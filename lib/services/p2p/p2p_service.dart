import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/map_objects/map_objects.dart';
import 'map_object_storage.dart';
import 'signaling_client.dart';
import 'p2p_connection.dart';
import 'sync_protocol.dart';
import '../../di/service_locator.dart';

/// Конфигурация P2P
class P2PConfig {
  final String signalingServerUrl;  // WebSocket URL: wss://kreagenium.ru/cm/ws/signaling
  final String zone;
  final String deviceId;
  final String app;
  final String? authSecret;  // HMAC secret для аутентификации (получить с сервера)
  final Duration syncInterval;
  final int listenPort;
  final ConflictResolution conflictResolution;

  const P2PConfig({
    required this.signalingServerUrl,
    required this.zone,
    required this.deviceId,
    this.app = 'progulkin',
    this.authSecret,
    this.syncInterval = const Duration(seconds: 30),
    this.listenPort = 9001,
    this.conflictResolution = ConflictResolution.lastWriteWins,
  });

  /// Legacy конструктор для совместимости
  factory P2PConfig.legacy({
    required String signalingServer,
    int signalingPort = 9000,
    required String zone,
    required String deviceId,
    String app = 'progulkin',
    String? authSecret,
    Duration syncInterval = const Duration(seconds: 30),
    int listenPort = 9001,
    ConflictResolution conflictResolution = ConflictResolution.lastWriteWins,
  }) {
    // Если указан порт 9000, это старый TCP сервер - игнорируем
    // Используем WSS через 443
    final useWss = signalingPort == 443 || signalingPort == 9000;
    final protocol = useWss ? 'wss' : 'ws';
    final port = (signalingPort == 9000) ? '' : ':$signalingPort';
    final url = '$protocol://$signalingServer$port/cm/ws/signaling';
    
    return P2PConfig(
      signalingServerUrl: url,
      zone: zone,
      deviceId: deviceId,
      app: app,
      authSecret: authSecret,
      syncInterval: syncInterval,
      listenPort: listenPort,
      conflictResolution: conflictResolution,
    );
  }
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
  final MapObjectStorage _storage = getIt<MapObjectStorage>();

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
        config: SignalingConfig(
          serverUrl: config.signalingServerUrl,
          deviceId: config.deviceId,
          app: config.app,
          zone: config.zone,
          listenPort: config.listenPort,
          authSecret: config.authSecret,
        ),
      );

      // Подписываемся на события сигнального сервера
      _signalingClient!.peerJoinedStream.listen(_handlePeerJoined);
      _signalingClient!.peerLeftStream.listen(_handlePeerLeft);
      _signalingClient!.peersStream.listen(_handlePeersList);
      _signalingClient!.errorStream.listen((error) {
        _errorController.add(error);
      });
      // Подписываемся на входящие сигналы
      _signalingClient!.signalStream.listen(_handleSignal);

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
      debugPrint('   URL: ${config.signalingServerUrl}');
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

  /// Обработка входящего signaling сообщения (WebRTC)
  void _handleSignal(Map<String, dynamic> signal) {
    final from = signal['from'] as String?;
    final signalType = signal['signalType'] as String?;
    final data = signal['data'] as Map<String, dynamic>?;

    if (from == null || signalType == null) return;

    debugPrint('📡 Сигнал от $from: $signalType');

    // TODO: Интеграция с WebRTC для P2P соединений
    // Сейчас просто логируем, WebRTC будет добавлен позже
    switch (signalType) {
      case 'offer':
        debugPrint('   Получен offer от $from');
        // WebRTC: создать answer
        break;
      case 'answer':
        debugPrint('   Получен answer от $from');
        // WebRTC: установить remote description
        break;
      case 'ice-candidate':
        debugPrint('   Получен ICE candidate от $from');
        // WebRTC: добавить ICE candidate
        break;
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
