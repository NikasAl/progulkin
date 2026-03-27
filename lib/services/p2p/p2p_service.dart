import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/map_objects/map_objects.dart';
import 'map_object_storage.dart';
import 'signaling_client.dart';
import 'p2p_connection.dart';
import 'sync_protocol.dart';

/// Конфигурация P2P
class P2PConfig {
  final String signalingServer;
  final int signalingPort;
  final String zone;
  final String deviceId;
  final Duration syncInterval;
  final int listenPort;
  final ConflictResolution conflictResolution;

  const P2PConfig({
    required this.signalingServer,
    this.signalingPort = 9000,
    required this.zone,
    required this.deviceId,
    this.syncInterval = const Duration(seconds: 30),
    this.listenPort = 9001,
    this.conflictResolution = ConflictResolution.lastWriteWins,
  });
}

/// Информация о пире
class Peer {
  final String id;
  final String zone;
  final bool isOnline;

  Peer({
    required this.id,
    required this.zone,
    this.isOnline = true,
  });
}

/// Результат синхронизации
class SyncResult {
  final int objectsReceived;
  final int objectsSent;
  final int objectsMerged;
  final List<String> errors;
  final Duration duration;

  SyncResult({
    this.objectsReceived = 0,
    this.objectsSent = 0,
    this.objectsMerged = 0,
    this.errors = const [],
    required this.duration,
  });

  bool get isSuccess => errors.isEmpty;
  bool get hasChanges => objectsReceived > 0 || objectsSent > 0 || objectsMerged > 0;
}

/// P2P сервис
/// Полная реализация peer-to-peer синхронизации
class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  final MapObjectStorage _storage = MapObjectStorage();

  P2PConfig? _config;
  bool _isRunning = false;

  SignalingClient? _signalingClient;
  P2PConnectionManager? _connectionManager;
  SyncProtocol? _syncProtocol;
  Timer? _syncTimer;
  Timer? _pingTimer;

  final StreamController<SyncResult> _syncController =
      StreamController<SyncResult>.broadcast();
  final StreamController<Peer> _peerController =
      StreamController<Peer>.broadcast();
  final StreamController<MapObject> _newObjectController =
      StreamController<MapObject>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<P2PState> _stateController =
      StreamController<P2PState>.broadcast();

  Stream<SyncResult> get syncStream => _syncController.stream;
  Stream<Peer> get peerStream => _peerController.stream;
  Stream<MapObject> get newObjectStream => _newObjectController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<P2PState> get stateStream => _stateController.stream;

  bool get isRunning => _isRunning;
  P2PState get state => _isRunning ? P2PState.running : P2PState.stopped;

  /// Запуск P2P сервиса
  Future<void> start(P2PConfig config) async {
    if (_isRunning) {
      debugPrint('⚠️ P2P сервис уже запущен');
      return;
    }

    _config = config;
    _isRunning = true;
    _stateController.add(P2PState.starting);

    try {
      // 1. Запускаем менеджер соединений
      _connectionManager = P2PConnectionManager(listenPort: config.listenPort);
      final listening = await _connectionManager!.startListening();

      if (!listening) {
        throw Exception('Не удалось запустить слушатель P2P');
      }

      // 2. Создаём протокол синхронизации
      _syncProtocol = SyncProtocol(
        storage: _storage,
        connectionManager: _connectionManager!,
        conflictResolution: config.conflictResolution,
      );

      // Подписываемся на новые объекты
      _syncProtocol!.objectReceivedStream.listen((obj) {
        _newObjectController.add(obj);
      });

      // 3. Подключаемся к сигнальному серверу
      _signalingClient = SignalingClient(
        serverHost: config.signalingServer,
        serverPort: config.signalingPort,
        deviceId: config.deviceId,
        zone: config.zone,
        listenPort: config.listenPort,
      );

      // Подписываемся на события сигнального сервера
      _signalingClient!.peerJoinedStream.listen(_handlePeerJoined);
      _signalingClient!.peerLeftStream.listen(_handlePeerLeft);
      _signalingClient!.peersStream.listen(_handlePeersList);
      _signalingClient!.errorStream.listen((error) {
        _errorController.add(error);
      });

      final connected = await _signalingClient!.connect();

      if (!connected) {
        debugPrint('⚠️ Не удалось подключиться к сигнальному серверу, работаем автономно');
      }

      // 4. Запускаем периодическую синхронизацию
      _syncTimer = Timer.periodic(config.syncInterval, (_) {
        _periodicSync();
      });

      // 5. Запускаем ping для поддержания соединений
      _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _sendPings();
      });

      _stateController.add(P2PState.running);
      debugPrint('🚀 P2P сервис запущен');
      debugPrint('   Зона: ${config.zone}');
      debugPrint('   Устройство: ${config.deviceId}');
      debugPrint('   Порт: ${config.listenPort}');
    } catch (e) {
      debugPrint('❌ Ошибка запуска P2P: $e');
      _isRunning = false;
      _stateController.add(P2PState.error);
      _errorController.add('Ошибка запуска: $e');
      rethrow;
    }
  }

  /// Остановка P2P сервиса
  Future<void> stop() async {
    if (!_isRunning) return;

    _syncTimer?.cancel();
    _pingTimer?.cancel();

    await _signalingClient?.disconnect();
    _syncProtocol?.dispose();
    await _connectionManager?.closeAll();

    _signalingClient = null;
    _connectionManager = null;
    _syncProtocol = null;

    _isRunning = false;
    _stateController.add(P2PState.stopped);

    debugPrint('🛑 P2P сервис остановлен');
  }

  /// Обработка подключения нового пира
  Future<void> _handlePeerJoined(PeerInfo peerInfo) async {
    debugPrint('👋 Новый пир: ${peerInfo.deviceId}');

    // Пытаемся подключиться к пиру
    final conn = await _connectionManager?.connectToPeer(
      peerInfo.deviceId,
      peerInfo.ip,
      peerInfo.port,
    );

    if (conn != null) {
      _peerController.add(Peer(
        id: peerInfo.deviceId,
        zone: peerInfo.zone,
        isOnline: true,
      ));

      // Запускаем синхронизацию с новым пиром
      await _syncProtocol?.requestSync(peerInfo.deviceId);
    }
  }

  /// Обработка отключения пира
  void _handlePeerLeft(String deviceId) {
    debugPrint('👋 Пир отключился: $deviceId');

    _peerController.add(Peer(
      id: deviceId,
      zone: _config?.zone ?? '',
      isOnline: false,
    ));

    _connectionManager?.disconnectFromPeer(deviceId);
  }

  /// Обработка списка пиров
  Future<void> _handlePeersList(List<PeerInfo> peers) async {
    debugPrint('📋 Получен список пиров: ${peers.length}');

    for (final peer in peers) {
      // Подключаемся к каждому пиру
      await _handlePeerJoined(peer);
    }
  }

  /// Периодическая синхронизация
  Future<void> _periodicSync() async {
    if (_syncProtocol == null) return;

    final startTime = DateTime.now();

    try {
      final stats = await _syncProtocol!.fullSync();

      _syncController.add(SyncResult(
        objectsReceived: stats.objectsReceived,
        objectsSent: stats.objectsSent,
        objectsMerged: stats.objectsMerged,
        duration: DateTime.now().difference(startTime),
      ));
    } catch (e) {
      debugPrint('❌ Ошибка периодической синхронизации: $e');
    }
  }

  /// Отправка ping всем пирам
  void _sendPings() {
    if (_connectionManager == null) return;

    for (final peerId in _connectionManager!.connectedPeers) {
      final conn = _connectionManager!.getConnection(peerId);
      conn?.sendPing();
    }
  }

  /// Создание и рассылка объекта
  Future<void> createAndBroadcastObject(MapObject object) async {
    // Сохраняем локально
    await _storage.saveObject(object);

    // Отправляем пирам
    await _syncProtocol?.broadcastObject(object);

    _newObjectController.add(object);
    debugPrint('📤 Объект ${object.id} создан и отправлен');
  }

  /// Обновление и рассылка объекта
  Future<void> updateAndBroadcastObject(MapObject object) async {
    // Обновляем локально
    await _storage.updateObject(object);

    // Отправляем пирам
    await _syncProtocol?.broadcastObject(object, isUpdate: true);

    debugPrint('📤 Объект ${object.id} обновлён и отправлен');
  }

  /// Удаление объекта
  Future<void> deleteAndBroadcastObject(String objectId) async {
    // Удаляем локально
    await _storage.deleteObject(objectId);

    // Уведомляем пиров
    _syncProtocol?.broadcastDelete(objectId);

    debugPrint('📤 Объект $objectId удалён и отправлено уведомление');
  }

  /// Принудительная синхронизация
  Future<void> forceSync() async {
    await _periodicSync();
  }

  /// Получить список подключенных пиров
  List<String> get connectedPeers => _connectionManager?.connectedPeers ?? [];

  /// Количество активных соединений
  int get activeConnectionsCount =>
      _connectionManager?.activeConnectionsCount ?? 0;

  void dispose() {
    stop();
    _syncController.close();
    _peerController.close();
    _newObjectController.close();
    _errorController.close();
    _stateController.close();
  }
}

/// Состояние P2P сервиса
enum P2PState {
  stopped,
  starting,
  running,
  error,
}
