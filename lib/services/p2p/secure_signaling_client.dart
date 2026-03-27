import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Состояние подключения к сигнальному серверу
enum SignalingState {
  disconnected,
  connecting,
  connected,
  authenticating,
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
      ip: json['ip'] as String,
      port: json['port'] as int,
    );
  }

  @override
  String toString() => 'Peer($deviceId at $ip:$port, zone=$zone)';
}

/// Конфигурация безопасного клиента
class SecureSignalingConfig {
  final String serverHost;
  final int serverPort;
  final bool useTLS;
  final String deviceId;
  final String zone;
  final int listenPort;
  final String? apiKey;
  final String? hmacSecret;
  final Duration connectTimeout;
  final Duration heartbeatInterval;
  final int maxReconnectAttempts;
  final Duration reconnectDelay;

  const SecureSignalingConfig({
    required this.serverHost,
    this.serverPort = 443,
    this.useTLS = true,
    required this.deviceId,
    required this.zone,
    this.listenPort = 9001,
    this.apiKey,
    this.hmacSecret,
    this.connectTimeout = const Duration(seconds: 10),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.maxReconnectAttempts = 5,
    this.reconnectDelay = const Duration(seconds: 3),
  });
}

/// Безопасный клиент сигнального сервера
class SecureSignalingClient {
  final SecureSignalingConfig config;

  Socket? _socket;
  SecureSocket? _secureSocket;
  SignalingState _state = SignalingState.disconnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

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

  Stream<SignalingState> get stateStream => _stateController.stream;
  Stream<List<PeerInfo>> get peersStream => _peersController.stream;
  Stream<PeerInfo> get peerJoinedStream => _peerJoinedController.stream;
  Stream<String> get peerLeftStream => _peerLeftController.stream;
  Stream<String> get errorStream => _errorController.stream;

  SignalingState get state => _state;
  bool get isConnected => _state == SignalingState.connected;

  SecureSignalingClient({required this.config});

  /// Подключиться к сигнальному серверу
  Future<bool> connect() async {
    if (_state == SignalingState.connected) {
      debugPrint('⚠️ Уже подключен к сигнальному серверу');
      return true;
    }

    _updateState(SignalingState.connecting);

    try {
      debugPrint('🔌 Подключение к сигнальному серверу ${config.serverHost}:${config.serverPort}');

      if (config.useTLS) {
        // Безопасное TLS соединение
        _secureSocket = await SecureSocket.connect(
          config.serverHost,
          config.serverPort,
          timeout: config.connectTimeout,
          onBadCertificate: _onBadCertificate,
        );

        _secureSocket!.listen(
          _handleData,
          onError: _handleError,
          onDone: _handleDone,
        );
      } else {
        // Обычное TCP (только для тестирования!)
        debugPrint('⚠️ Используется незащищённое соединение!');
        _socket = await Socket.connect(
          config.serverHost,
          config.serverPort,
          timeout: config.connectTimeout,
        );

        _socket!.listen(
          _handleData,
          onError: _handleError,
          onDone: _handleDone,
        );
      }

      // Аутентификация
      _updateState(SignalingState.authenticating);
      await _authenticate();

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

  /// Проверка сертификата
  bool _onBadCertificate(X509Certificate cert) {
    // В продакшене нужно проверять сертификат
    // Например, pinning конкретного сертификата
    debugPrint('⚠️ Проблема с сертификатом: ${cert.subject}');

    // Для разработки разрешаем (в продакшене вернуть false!)
    return true;
  }

  /// Аутентификация на сервере
  Future<void> _authenticate() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // Генерируем HMAC подпись если есть секрет
    String? signature;
    if (config.hmacSecret != null) {
      signature = _generateHmac(config.deviceId, timestamp, config.hmacSecret!);
    }

    // Формируем параметры для WebSocket
    // В реальной реализации это был бы query string при подключении
    final authMessage = {
      'type': 'register',
      'deviceId': config.deviceId,
      'zone': config.zone,
      'port': config.listenPort,
      'timestamp': timestamp,
      if (signature != null) 'signature': signature,
      if (config.apiKey != null) 'apiKey': config.apiKey,
    };

    _send(authMessage);
  }

  /// Генерация HMAC подписи
  String _generateHmac(String deviceId, String timestamp, String secret) {
    final message = '$deviceId:$timestamp';
    final key = utf8.encode(secret);
    final bytes = utf8.encode(message);

    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);

    return digest.toString();
  }

  /// Отключиться от сервера
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_secureSocket != null) {
      try {
        _send({'type': 'leave', 'deviceId': config.deviceId});
        await Future.delayed(const Duration(milliseconds: 100));
        await _secureSocket!.close();
      } catch (e) {
        debugPrint('⚠️ Ошибка при отключении: $e');
      }
      _secureSocket = null;
    }

    if (_socket != null) {
      try {
        _send({'type': 'leave', 'deviceId': config.deviceId});
        await Future.delayed(const Duration(milliseconds: 100));
        await _socket!.close();
      } catch (e) {
        debugPrint('⚠️ Ошибка при отключении: $e');
      }
      _socket = null;
    }

    _updateState(SignalingState.disconnected);
    debugPrint('👋 Отключен от сигнального сервера');
  }

  /// Запросить список пиров
  void requestPeers() {
    if (!isConnected) return;
    _send({
      'type': 'get_peers',
      'deviceId': config.deviceId,
      'zone': config.zone,
    });
  }

  /// Обработка входящих данных
  void _handleData(List<int> data) {
    try {
      final message = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
      _handleMessage(message);
    } catch (e) {
      debugPrint('⚠️ Ошибка разбора сообщения: $e');
    }
  }

  /// Обработка сообщения от сервера
  void _handleMessage(Map<String, dynamic> message) {
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
    final peer = PeerInfo(
      deviceId: message['deviceId'] as String,
      zone: message['zone'] as String,
      ip: message['ip'] as String,
      port: message['port'] as int,
    );

    debugPrint('👋 Новый пир: $peer');
    _peerJoinedController.add(peer);
  }

  /// Обработка отключения пира
  void _handlePeerLeft(Map<String, dynamic> message) {
    final deviceId = message['deviceId'] as String;
    debugPrint('👋 Пир отключился: $deviceId');
    _peerLeftController.add(deviceId);
  }

  /// Обработка ошибки сокета
  void _handleError(dynamic error) {
    debugPrint('❌ Ошибка сокета: $error');
    _updateState(SignalingState.error);
    _errorController.add('Ошибка сокета: $error');
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
    try {
      final data = utf8.encode(jsonEncode(message));
      if (_secureSocket != null) {
        _secureSocket!.add(data);
      } else if (_socket != null) {
        _socket!.add(data);
      }
    } catch (e) {
      debugPrint('❌ Ошибка отправки: $e');
    }
  }

  /// Запуск heartbeat
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(config.heartbeatInterval, (_) {
      if (isConnected) {
        _send({
          'type': 'heartbeat',
          'deviceId': config.deviceId,
        });
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
  }
}
