import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Состояние подключения к сигнальному серверу
enum SignalingState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Информация о пире
class PeerInfo {
  final String deviceId;
  final String zone;
  final String ip;
  final int port;

  PeerInfo({
    required this.deviceId,
    required this.zone,
    required this.ip,
    required this.port,
  });

  factory PeerInfo.fromJson(Map<String, dynamic> json) {
    return PeerInfo(
      deviceId: json['deviceId'] as String,
      zone: json['zone'] as String,
      ip: json['ip'] as String? ?? '',
      port: json['port'] as int? ?? 9001,
    );
  }

  @override
  String toString() => 'Peer($deviceId at $ip:$port, zone=$zone)';
}

/// Конфигурация WebSocket signaling клиента
class SignalingConfig {
  final String serverUrl;      // e.g., wss://kreagenium.ru/cm/ws/signaling
  final String deviceId;
  final String app;
  final String zone;
  final int listenPort;
  final Duration heartbeatInterval;
  final int maxReconnectAttempts;
  final Duration reconnectDelay;

  const SignalingConfig({
    required this.serverUrl,
    required this.deviceId,
    this.app = 'progulkin',
    required this.zone,
    this.listenPort = 9001,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.maxReconnectAttempts = 5,
    this.reconnectDelay = const Duration(seconds: 3),
  });
}

/// WebSocket клиент сигнального сервера
/// Работает через HTTPS 443 (wss://)
class SignalingClient {
  final SignalingConfig config;

  WebSocketChannel? _channel;
  SignalingState _state = SignalingState.disconnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  StreamSubscription? _subscription;

  final StreamController<SignalingState> _stateController =
      StreamController<SignalingState>.broadcast();
  final StreamController<List<PeerInfo>> _peersController =
      StreamController<List<PeerInfo>>.broadcast();
  final StreamController<PeerInfo> _peerJoinedController =
      StreamController<PeerInfo>.broadcast();
  final StreamController<String> _peerLeftController =
      StreamController<String>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _signalController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Поток изменений состояния
  Stream<SignalingState> get stateStream => _stateController.stream;

  /// Поток обновлений списка пиров
  Stream<List<PeerInfo>> get peersStream => _peersController.stream;

  /// Поток событий подключения нового пира
  Stream<PeerInfo> get peerJoinedStream => _peerJoinedController.stream;

  /// Поток событий отключения пира
  Stream<String> get peerLeftStream => _peerLeftController.stream;

  /// Поток ошибок
  Stream<String> get errorStream => _errorController.stream;

  /// Поток входящих сигналов (offer, answer, ice-candidate)
  Stream<Map<String, dynamic>> get signalStream => _signalController.stream;

  /// Текущее состояние
  SignalingState get state => _state;

  /// Подключен ли к серверу
  bool get isConnected => _state == SignalingState.connected;

  SignalingClient({required this.config});

  /// Создать клиент с legacy параметрами (для совместимости)
  factory SignalingClient.legacy({
    required String serverHost,
    int serverPort = 9000,
    required String deviceId,
    required String zone,
    int listenPort = 9001,
    String app = 'progulkin',
    bool useWss = true,
  }) {
    final protocol = useWss ? 'wss' : 'ws';
    final url = '$protocol://$serverPort/cm/ws/signaling';
    // Если порт 443 или 80, не включаем его в URL
    final defaultPort = useWss ? 443 : 80;
    final urlWithPort = serverPort == defaultPort
        ? '$protocol://$serverHost/cm/ws/signaling'
        : '$protocol://$serverHost:$serverPort/cm/ws/signaling';

    return SignalingClient(
      config: SignalingConfig(
        serverUrl: urlWithPort,
        deviceId: deviceId,
        app: app,
        zone: zone,
        listenPort: listenPort,
      ),
    );
  }

  /// Подключиться к сигнальному серверу
  Future<bool> connect() async {
    if (_state == SignalingState.connected) {
      debugPrint('⚠️ Уже подключен к сигнальному серверу');
      return true;
    }

    _updateState(SignalingState.connecting);

    try {
      debugPrint('🔌 Подключение к сигнальному серверу: ${config.serverUrl}');

      _channel = WebSocketChannel.connect(
        Uri.parse(config.serverUrl),
      );

      // Ждем подключения
      await _channel!.ready;

      // Подписываемся на сообщения
      _subscription = _channel!.stream.listen(
        _handleData,
        onError: _handleError,
        onDone: _handleDone,
      );

      // Регистрируемся на сервере
      await _register();

      // Запускаем heartbeat
      _startHeartbeat();

      _reconnectAttempts = 0;
      _updateState(SignalingState.connected);
      debugPrint('✅ Подключен к сигнальному серверу');

      return true;
    } catch (e) {
      debugPrint('❌ Ошибка подключения к сигнальному серверу: $e');
      _updateState(SignalingState.error);
      _errorController.add('Ошибка подключения: $e');

      _scheduleReconnect();

      return false;
    }
  }

  /// Отключиться от сервера
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_channel != null) {
      try {
        await _subscription?.cancel();
        await _channel!.sink.close();
      } catch (e) {
        debugPrint('⚠️ Ошибка при отключении: $e');
      }
      _channel = null;
      _subscription = null;
    }

    _updateState(SignalingState.disconnected);
    debugPrint('👋 Отключен от сигнального сервера');
  }

  /// Запросить список пиров
  void requestPeers() {
    if (!isConnected) return;
    _send({'type': 'get_peers'});
  }

  /// Отправить signaling сообщение (offer, answer, ice-candidate)
  void sendSignal(String targetDeviceId, String signalType, Map<String, dynamic> data) {
    if (!isConnected) return;
    _send({
      'type': 'signal',
      'to': targetDeviceId,
      'signalType': signalType,
      'data': data,
    });
  }

  /// Регистрация на сервере
  Future<void> _register() async {
    _send({
      'type': 'register',
      'deviceId': config.deviceId,
      'app': config.app,
      'zone': config.zone,
      'port': config.listenPort,
    });
  }

  /// Обработка входящих данных
  void _handleData(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      _handleMessage(message);
    } catch (e) {
      debugPrint('⚠️ Ошибка разбора сообщения: $e');
    }
  }

  /// Обработка сообщения от сервера
  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'registered':
        // Подтверждение регистрации
        final peers = (message['peers'] as List? ?? [])
            .map((p) => PeerInfo.fromJson(p as Map<String, dynamic>))
            .toList();
        debugPrint('📋 Зарегистрирован, пиров в зоне: ${peers.length}');
        _peersController.add(peers);
        break;

      case 'peers':
        _handlePeersList(message);
        break;

      case 'peer_joined':
        _handlePeerJoined(message);
        break;

      case 'peer_left':
        _handlePeerLeft(message);
        break;

      case 'signal':
        // Входящий сигнал от другого пира
        debugPrint('📡 Получен сигнал от ${message['from']}: ${message['signalType']}');
        _signalController.add(message);
        break;

      case 'heartbeat_ack':
        // Heartbeat подтверждён
        break;

      case 'error':
        final errorMsg = message['message'] as String?;
        debugPrint('❌ Ошибка от сервера: $errorMsg');
        _errorController.add(errorMsg ?? 'Unknown error');
        break;

      default:
        debugPrint('❓ Неизвестное сообщение: $type');
    }
  }

  /// Обработка списка пиров
  void _handlePeersList(Map<String, dynamic> message) {
    final peersList = message['peers'] as List? ?? [];
    final peers = peersList
        .map((p) => PeerInfo.fromJson(p as Map<String, dynamic>))
        .toList();

    debugPrint('📋 Получен список пиров: ${peers.length}');
    _peersController.add(peers);
  }

  /// Обработка подключения нового пира
  void _handlePeerJoined(Map<String, dynamic> message) {
    final peerData = message['peer'] as Map<String, dynamic>? ?? message;
    final peer = PeerInfo.fromJson(peerData);

    debugPrint('👋 Новый пир: $peer');
    _peerJoinedController.add(peer);
  }

  /// Обработка отключения пира
  void _handlePeerLeft(Map<String, dynamic> message) {
    final deviceId = message['deviceId'] as String;
    debugPrint('👋 Пир отключился: $deviceId');
    _peerLeftController.add(deviceId);
  }

  /// Обработка ошибки
  void _handleError(dynamic error) {
    debugPrint('❌ Ошибка WebSocket: $error');
    _updateState(SignalingState.error);
    _errorController.add('Ошибка WebSocket: $error');
    _scheduleReconnect();
  }

  /// Обработка закрытия соединения
  void _handleDone() {
    debugPrint('🔌 Соединение закрыто сервером');
    _updateState(SignalingState.disconnected);
    _scheduleReconnect();
  }

  /// Отправка сообщения
  void _send(Map<String, dynamic> message) {
    if (_channel == null) return;

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('❌ Ошибка отправки: $e');
    }
  }

  /// Запуск heartbeat
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(config.heartbeatInterval, (_) {
      if (isConnected) {
        _send({'type': 'heartbeat'});
      }
    });
  }

  /// Планирование переподключения с exponential backoff
  void _scheduleReconnect() {
    if (_reconnectAttempts >= config.maxReconnectAttempts) {
      debugPrint('❌ Достигнут лимит попыток переподключения');
      return;
    }

    _reconnectTimer?.cancel();

    // Exponential backoff: 3s, 6s, 12s, 24s, 48s
    final delay = Duration(
      milliseconds: config.reconnectDelay.inMilliseconds *
          (1 << _reconnectAttempts.clamp(0, 5)),
    );

    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () {
      if (_state != SignalingState.connected) {
        debugPrint('🔄 Попытка переподключения ($_reconnectAttempts/${config.maxReconnectAttempts})...');
        connect();
      }
    });
  }

  /// Обновление состояния
  void _updateState(SignalingState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// Освобождение ресурсов
  void dispose() {
    disconnect();
    _stateController.close();
    _peersController.close();
    _peerJoinedController.close();
    _peerLeftController.close();
    _errorController.close();
    _signalController.close();
  }
}
