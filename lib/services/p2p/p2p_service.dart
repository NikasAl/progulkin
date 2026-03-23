import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/map_objects/map_objects.dart';
import 'map_object_storage.dart';

/// Конфигурация P2P
class P2PConfig {
  final String signalingServer;
  final int signalingPort;
  final int localPort;
  final String zone;
  final String deviceId;
  final Duration syncInterval;
  final int maxPeers;
  final int syncRadiusMeters;

  const P2PConfig({
    required this.signalingServer,
    this.signalingPort = 9000,
    this.localPort = 9001,
    required this.zone,
    required this.deviceId,
    this.syncInterval = const Duration(seconds: 30),
    this.maxPeers = 10,
    this.syncRadiusMeters = 10000, // 10 км
  });
}

/// Информация о пире
class Peer {
  final String id;
  final String zone;
  final String publicIp;
  final int port;
  final DateTime lastSeen;
  final bool isOnline;

  Peer({
    required this.id,
    required this.zone,
    required this.publicIp,
    required this.port,
    DateTime? lastSeen,
    this.isOnline = true,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Duration get age => DateTime.now().difference(lastSeen);
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
  bool get hasChanges => objectsReceived > 0 || objectsSent > 0;
}

/// P2P сервис синхронизации объектов карты
class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  final MapObjectStorage _storage = MapObjectStorage();
  final Uuid _uuid = const Uuid();

  P2PConfig? _config;
  Socket? _signalingSocket;
  RawDatagramSocket? _p2pSocket;
  final Map<String, Peer> _peers = {};
  final List<String> _connectedPeers = [];

  final StreamController<SyncResult> _syncController =
      StreamController<SyncResult>.broadcast();
  final StreamController<Peer> _peerController =
      StreamController<Peer>.broadcast();
  final StreamController<MapObject> _newObjectController =
      StreamController<MapObject>.broadcast();

  Stream<SyncResult> get syncStream => _syncController.stream;
  Stream<Peer> get peerStream => _peerController.stream;
  Stream<MapObject> get newObjectStream => _newObjectController.stream;

  bool _isRunning = false;
  Timer? _syncTimer;
  Timer? _heartbeatTimer;

  /// Инициализация и запуск P2P сервиса
  Future<void> start(P2PConfig config) async {
    if (_isRunning) {
      print('P2P сервис уже запущен');
      return;
    }

    _config = config;
    print('🚀 Запуск P2P сервиса...');
    print('   Зона: ${config.zone}');
    print('   Сигнальный сервер: ${config.signalingServer}:${config.signalingPort}');

    try {
      // 1. Подключаемся к сигнальному серверу
      await _connectToSignaling();

      // 2. Открываем P2P сокет
      await _bindP2PSocket();

      // 3. Регистрируемся в зоне
      _registerInZone();

      // 4. Запускаем периодическую синхронизацию
      _startPeriodicSync();

      // 5. Запускаем heartbeat
      _startHeartbeat();

      _isRunning = true;
      print('✅ P2P сервис запущен');
    } catch (e) {
      print('❌ Ошибка запуска P2P: $e');
      rethrow;
    }
  }

  /// Остановка P2P сервиса
  Future<void> stop() async {
    if (!_isRunning) return;

    print('🛑 Остановка P2P сервиса...');

    _syncTimer?.cancel();
    _heartbeatTimer?.cancel();

    // Отправляем сообщение о выходе
    if (_signalingSocket != null) {
      _sendToSignaling({
        'type': 'leave',
        'zone': _config!.zone,
        'deviceId': _config!.deviceId,
      });
    }

    _signalingSocket?.destroy();
    _p2pSocket?.close();

    _peers.clear();
    _connectedPeers.clear();
    _isRunning = false;

    print('✅ P2P сервис остановлен');
  }

  /// Подключение к сигнальному серверу
  Future<void> _connectToSignaling() async {
    final completer = Completer<void>();

    try {
      _signalingSocket = await Socket.connect(
        _config!.signalingServer,
        _config!.signalingPort,
        timeout: const Duration(seconds: 10),
      );

      _signalingSocket!.listen(
        (data) => _handleSignalingMessage(data),
        onError: (error) {
          print('❌ Ошибка сигнального сокета: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          print('📡 Сигнальное соединение закрыто');
          _reconnect();
        },
      );

      // Даём время на установку соединения
      await Future.delayed(const Duration(milliseconds: 500));
      completer.complete();
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  /// Обработка сообщений от сигнального сервера
  void _handleSignalingMessage(List<int> data) {
    try {
      final message = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'peers':
          _handlePeersList(message);
          break;
        case 'peer_joined':
          _handlePeerJoined(message);
          break;
        case 'peer_left':
          _handlePeerLeft(message);
          break;
        case 'punch_request':
          _handlePunchRequest(message);
          break;
        default:
          print('❓ Неизвестный тип сообщения: $type');
      }
    } catch (e) {
      print('❌ Ошибка обработки сообщения: $e');
    }
  }

  /// Привязка P2P сокета
  Future<void> _bindP2PSocket() async {
    _p2pSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _config!.localPort,
    );

    _p2pSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _p2pSocket!.receive();
        if (datagram != null) {
          _handleP2PMessage(datagram);
        }
      }
    });

    print('📡 P2P сокет открыт на порту ${_config!.localPort}');
  }

  /// Обработка P2P сообщений
  void _handleP2PMessage(Datagram datagram) {
    try {
      final message = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'sync_request':
          _handleSyncRequest(message, datagram.address, datagram.port);
          break;
        case 'sync_data':
          _handleSyncData(message);
          break;
        case 'object_update':
          _handleObjectUpdate(message);
          break;
        case 'ping':
          _handlePing(message, datagram.address, datagram.port);
          break;
        case 'pong':
          // Pong received, peer is alive
          break;
      }
    } catch (e) {
      print('❌ Ошибка обработки P2P сообщения: $e');
    }
  }

  /// Регистрация в зоне
  void _registerInZone() {
    _sendToSignaling({
      'type': 'register',
      'zone': _config!.zone,
      'deviceId': _config!.deviceId,
      'port': _config!.localPort,
    });
  }

  /// Обработка списка пиров
  void _handlePeersList(Map<String, dynamic> message) {
    final peers = message['peers'] as List? ?? [];

    for (final peerData in peers) {
      final peer = Peer(
        id: peerData['deviceId'] as String,
        zone: peerData['zone'] as String,
        publicIp: peerData['ip'] as String,
        port: peerData['port'] as int,
      );

      if (peer.id != _config!.deviceId) {
        _peers[peer.id] = peer;
        _peerController.add(peer);
        print('👁️ Найден пир: ${peer.id} (${peer.publicIp}:${peer.port})');
      }
    }

    // Инициируем синхронизацию с найденными пирами
    _initiateSyncWithPeers();
  }

  /// Обработка нового пира
  void _handlePeerJoined(Map<String, dynamic> message) {
    final peerId = message['deviceId'] as String;
    if (peerId == _config!.deviceId) return;

    final peer = Peer(
      id: peerId,
      zone: message['zone'] as String,
      publicIp: message['ip'] as String,
      port: message['port'] as int,
    );

    _peers[peerId] = peer;
    _peerController.add(peer);
    print('👋 Новый пир: $peerId');

    // Синхронизируемся с новым пиром
    _syncWithPeer(peer);
  }

  /// Обработка ухода пира
  void _handlePeerLeft(Map<String, dynamic> message) {
    final peerId = message['deviceId'] as String;
    _peers.remove(peerId);
    _connectedPeers.remove(peerId);
    print('👋 Пир ушёл: $peerId');
  }

  /// UDP Hole Punching запрос
  void _handlePunchRequest(Map<String, dynamic> message) {
    final targetIp = message['targetIp'] as String;
    final targetPort = message['targetPort'] as int;

    // Отправляем пакет для пробития NAT
    _sendP2P(
      InternetAddress(targetIp),
      targetPort,
      {'type': 'ping', 'deviceId': _config!.deviceId},
    );
  }

  /// Инициация синхронизации со всеми пирами
  void _initiateSyncWithPeers() {
    for (final peer in _peers.values) {
      if (!_connectedPeers.contains(peer.id)) {
        _syncWithPeer(peer);
      }
    }
  }

  /// Синхронизация с конкретным пиром
  Future<SyncResult> _syncWithPeer(Peer peer) async {
    final stopwatch = Stopwatch()..start();
    int received = 0;
    int sent = 0;
    int merged = 0;
    final errors = <String>[];

    try {
      // Отправляем запрос на синхронизацию
      final myObjects = await _storage.getAllObjects();

      _sendP2P(
        InternetAddress(peer.publicIp),
        peer.port,
        {
          'type': 'sync_request',
          'deviceId': _config!.deviceId,
          'objectCount': myObjects.length,
          'objects': myObjects.map((o) => o.toSyncJson()).toList(),
        },
      );

      sent = myObjects.length;
      _connectedPeers.add(peer.id);

      print('📤 Отправлено $sent объектов пиру ${peer.id}');
    } catch (e) {
      errors.add(e.toString());
      print('❌ Ошибка синхронизации с ${peer.id}: $e');
    }

    return SyncResult(
      objectsReceived: received,
      objectsSent: sent,
      objectsMerged: merged,
      errors: errors,
      duration: stopwatch.elapsed,
    );
  }

  /// Обработка запроса на синхронизацию
  Future<void> _handleSyncRequest(
    Map<String, dynamic> message,
    InternetAddress address,
    int port,
  ) async {
    final peerId = message['deviceId'] as String;
    final theirObjects = (message['objects'] as List?)
        ?.map((e) => MapObject.fromSyncJson(e as Map<String, dynamic>))
        .toList() ?? [];

    print('📥 Получено ${theirObjects.length} объектов от $peerId');

    // Мержим полученные объекты
    int merged = 0;
    for (final obj in theirObjects) {
      final existing = await _storage.getObject(obj.id);

      if (existing == null) {
        // Новый объект
        await _storage.saveObject(obj);
        _newObjectController.add(obj);
        merged++;
      } else if (obj.version > existing.version) {
        // Более новая версия
        await _storage.saveObject(obj);
        merged++;
      }
    }

    // Отправляем свои объекты в ответ
    final myObjects = await _storage.getAllObjects();
    _sendP2P(
      address,
      port,
      {
        'type': 'sync_data',
        'deviceId': _config!.deviceId,
        'objects': myObjects.map((o) => o.toSyncJson()).toList(),
        'merged': merged,
      },
    );

    print('📤 Отправлено ${myObjects.length} объектов в ответ');
  }

  /// Обработка данных синхронизации
  Future<void> _handleSyncData(Map<String, dynamic> message) async {
    final theirObjects = (message['objects'] as List?)
        ?.map((e) => MapObject.fromSyncJson(e as Map<String, dynamic>))
        .toList() ?? [];

    for (final obj in theirObjects) {
      final existing = await _storage.getObject(obj.id);

      if (existing == null) {
        await _storage.saveObject(obj);
        _newObjectController.add(obj);
      } else if (obj.version > existing.version) {
        await _storage.saveObject(obj);
      }
    }

    print('📥 Синхронизировано ${theirObjects.length} объектов');
  }

  /// Обработка обновления объекта
  Future<void> _handleObjectUpdate(Map<String, dynamic> message) async {
    final data = message['object'] as Map<String, dynamic>;
    final obj = MapObject.fromSyncJson(data);

    final existing = await _storage.getObject(obj.id);
    if (existing == null || obj.version > existing.version) {
      await _storage.saveObject(obj);
      _newObjectController.add(obj);
      print('📝 Объект обновлён: ${obj.id}');
    }
  }

  /// Обработка ping
  void _handlePing(Map<String, dynamic> message, InternetAddress address, int port) {
    _sendP2P(address, port, {
      'type': 'pong',
      'deviceId': _config!.deviceId,
    });
  }

  /// Отправка сообщения на сигнальный сервер
  void _sendToSignaling(Map<String, dynamic> message) {
    if (_signalingSocket == null) return;

    final data = utf8.encode(jsonEncode(message));
    _signalingSocket!.add(data);
  }

  /// Отправка P2P сообщения
  void _sendP2P(InternetAddress address, int port, Map<String, dynamic> message) {
    if (_p2pSocket == null) return;

    final data = utf8.encode(jsonEncode(message));
    _p2pSocket!.send(data, address, port);
  }

  /// Периодическая синхронизация
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(_config!.syncInterval, (_) {
      _initiateSyncWithPeers();
    });
  }

  /// Heartbeat для поддержания соединения
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendToSignaling({
        'type': 'heartbeat',
        'zone': _config!.zone,
        'deviceId': _config!.deviceId,
      });
    });
  }

  /// Переподключение при разрыве
  void _reconnect() {
    if (!_isRunning) return;

    Future.delayed(const Duration(seconds: 5), () {
      if (_isRunning) {
        print('🔄 Переподключение к сигнальному серверу...');
        _connectToSignaling().then((_) {
          _registerInZone();
        }).catchError((e) {
          print('❌ Ошибка переподключения: $e');
          _reconnect();
        });
      }
    });
  }

  /// Публичный метод для создания объекта и рассылки
  Future<void> createAndBroadcastObject(MapObject object) async {
    // Сохраняем локально
    await _storage.saveObject(object);

    // Рассылаем всем пирам
    for (final peer in _peers.values) {
      _sendP2P(
        InternetAddress(peer.publicIp),
        peer.port,
        {
          'type': 'object_update',
          'deviceId': _config!.deviceId,
          'object': object.toSyncJson(),
        },
      );
    }

    print('📤 Объект создан и разослан: ${object.id}');
  }

  /// Получить список активных пиров
  List<Peer> get activePeers => _peers.values.where((p) => p.isOnline).toList();

  /// Проверка активности
  bool get isRunning => _isRunning;

  /// Принудительная синхронизация
  Future<void> forceSync() async {
    _initiateSyncWithPeers();
  }

  void dispose() {
    stop();
    _syncController.close();
    _peerController.close();
    _newObjectController.close();
  }
}
