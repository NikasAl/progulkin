import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

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
      ip: json['ip'] as String,
      port: json['port'] as int,
    );
  }

  @override
  String toString() => 'Peer($deviceId at $ip:$port, zone=$zone)';
}

/// Клиент сигнального сервера
/// Управляет подключением и получает информацию о пирах
class SignalingClient {
  final String serverHost;
  final int serverPort;
  final String deviceId;
  final String zone;
  final int listenPort;

  Socket? _socket;
  SignalingState _state = SignalingState.disconnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

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

  /// Текущее состояние
  SignalingState get state => _state;

  /// Подключен ли к серверу
  bool get isConnected => _state == SignalingState.connected;

  SignalingClient({
    required this.serverHost,
    this.serverPort = 9000,
    required this.deviceId,
    required this.zone,
    this.listenPort = 9001,
  });

  /// Подключиться к сигнальному серверу
  Future<bool> connect() async {
    if (_state == SignalingState.connected) {
      debugPrint('⚠️ Уже подключен к сигнальному серверу');
      return true;
    }

    _updateState(SignalingState.connecting);

    try {
      debugPrint('🔌 Подключение к сигнальному серверу $serverHost:$serverPort');

      _socket = await Socket.connect(
        serverHost,
        serverPort,
        timeout: const Duration(seconds: 10),
      );

      // Обработка входящих данных
      _socket!.listen(
        _handleData,
        onError: _handleError,
        onDone: _handleDone,
      );

      // Регистрируемся на сервере
      await _register();

      // Запускаем heartbeat
      _startHeartbeat();

      _updateState(SignalingState.connected);
      debugPrint('✅ Подключен к сигнальному серверу');

      return true;
    } catch (e) {
      debugPrint('❌ Ошибка подключения к сигнальному серверу: $e');
      _updateState(SignalingState.error);
      _errorController.add('Ошибка подключения: $e');

      // Планируем переподключение
      _scheduleReconnect();

      return false;
    }
  }

  /// Отключиться от сервера
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_socket != null) {
      try {
        // Отправляем сообщение о выходе
        _send({'type': 'leave', 'deviceId': deviceId});
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
      'deviceId': deviceId,
      'zone': zone,
    });
  }

  /// Регистрация на сервере
  Future<void> _register() async {
    _send({
      'type': 'register',
      'deviceId': deviceId,
      'zone': zone,
      'port': listenPort,
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
    if (_socket == null) return;

    try {
      final data = utf8.encode(jsonEncode(message));
      _socket!.add(data);
    } catch (e) {
      debugPrint('❌ Ошибка отправки: $e');
    }
  }

  /// Запуск heartbeat
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isConnected) {
        _send({
          'type': 'heartbeat',
          'deviceId': deviceId,
        });
      }
    });
  }

  /// Планирование переподключения
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_state != SignalingState.connected) {
        debugPrint('🔄 Попытка переподключения...');
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
