import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Тип сообщения P2P
enum P2PMessageType {
  syncRequest,
  syncResponse,
  objectCreate,
  objectUpdate,
  objectDelete,
  interestAdd,
  interestRemove,
  contactProfileUpdate,
  ping,
  pong,
}

/// P2P сообщение
class P2PMessage {
  final P2PMessageType type;
  final Map<String, dynamic>? payload;
  final DateTime timestamp;

  P2PMessage({
    required this.type,
    this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String toJson() => jsonEncode({
        'type': type.name,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      });

  factory P2PMessage.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return P2PMessage(
      type: P2PMessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => P2PMessageType.ping,
      ),
      payload: json['payload'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Состояние соединения с пиром
enum PeerConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Соединение с конкретным пиром
class PeerConnection {
  final String deviceId;
  final String ip;
  final int port;

  Socket? _socket;
  PeerConnectionState _state = PeerConnectionState.disconnected;

  final StreamController<P2PMessage> _messageController =
      StreamController<P2PMessage>.broadcast();
  final StreamController<PeerConnectionState> _stateController =
      StreamController<PeerConnectionState>.broadcast();

  Stream<P2PMessage> get messageStream => _messageController.stream;
  Stream<PeerConnectionState> get stateStream => _stateController.stream;
  PeerConnectionState get state => _state;
  bool get isConnected => _state == PeerConnectionState.connected;

  PeerConnection({
    required this.deviceId,
    required this.ip,
    required this.port,
  });

  /// Подключиться к пиру (исходящее соединение)
  Future<bool> connect() async {
    if (isConnected) return true;

    _updateState(PeerConnectionState.connecting);

    try {
      debugPrint('🔌 Подключение к пиру $deviceId ($ip:$port)');

      _socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );

      _socket!.listen(
        _handleData,
        onError: _handleError,
        onDone: _handleDone,
      );

      _updateState(PeerConnectionState.connected);
      debugPrint('✅ Подключен к пиру $deviceId');

      return true;
    } catch (e) {
      debugPrint('❌ Ошибка подключения к пиру: $e');
      _updateState(PeerConnectionState.error);
      return false;
    }
  }

  /// Принять входящее соединение
  void acceptConnection(Socket socket) {
    if (isConnected) {
      socket.destroy();
      return;
    }

    _socket = socket;
    _socket!.listen(
      _handleData,
      onError: _handleError,
      onDone: _handleDone,
    );

    _updateState(PeerConnectionState.connected);
    debugPrint('✅ Принято входящее соединение от $deviceId');
  }

  /// Отключиться
  Future<void> disconnect() async {
    try {
      await _socket?.close();
    } catch (e) {
      debugPrint('⚠️ Ошибка при отключении: $e');
    }
    _socket = null;
    _updateState(PeerConnectionState.disconnected);
  }

  /// Отправить сообщение
  bool sendMessage(P2PMessage message) {
    if (!isConnected || _socket == null) return false;

    try {
      final json = message.toJson();
      final data = utf8.encode('$json\n'); // \n как разделитель сообщений
      _socket!.add(data);
      return true;
    } catch (e) {
      debugPrint('❌ Ошибка отправки сообщения: $e');
      return false;
    }
  }

  /// Отправить запрос синхронизации
  void sendSyncRequest(List<String> objectIds, int sinceVersion) {
    sendMessage(P2PMessage(
      type: P2PMessageType.syncRequest,
      payload: {
        'objectIds': objectIds,
        'sinceVersion': sinceVersion,
      },
    ));
  }

  /// Отправить объект
  void sendObject(Map<String, dynamic> objectJson, {bool isUpdate = false}) {
    sendMessage(P2PMessage(
      type: isUpdate ? P2PMessageType.objectUpdate : P2PMessageType.objectCreate,
      payload: objectJson,
    ));
  }

  /// Отправить ping
  void sendPing() {
    sendMessage(P2PMessage(type: P2PMessageType.ping));
  }

  /// Обработка входящих данных
  void _handleData(List<int> data) {
    try {
      final messageStr = utf8.decode(data).trim();
      if (messageStr.isEmpty) return;

      final message = P2PMessage.fromJson(messageStr);

      // Автоответ на ping
      if (message.type == P2PMessageType.ping) {
        sendMessage(P2PMessage(type: P2PMessageType.pong));
        return;
      }

      _messageController.add(message);
    } catch (e) {
      debugPrint('⚠️ Ошибка разбора P2P сообщения: $e');
    }
  }

  void _handleError(dynamic error) {
    debugPrint('❌ Ошибка соединения с пиром: $error');
    _updateState(PeerConnectionState.error);
  }

  void _handleDone() {
    debugPrint('🔌 Соединение с пиром закрыто');
    _updateState(PeerConnectionState.disconnected);
  }

  void _updateState(PeerConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
  }
}

/// Менеджер P2P соединений
/// Управляет входящими и исходящими соединениями
class P2PConnectionManager {
  final int listenPort;

  ServerSocket? _serverSocket;
  final Map<String, PeerConnection> _connections = {};

  final StreamController<P2PMessage> _messageController =
      StreamController<P2PMessage>.broadcast();
  final StreamController<String> _connectionOpenedController =
      StreamController<String>.broadcast();
  final StreamController<String> _connectionClosedController =
      StreamController<String>.broadcast();

  Stream<P2PMessage> get messageStream => _messageController.stream;
  Stream<String> get connectionOpenedStream => _connectionOpenedController.stream;
  Stream<String> get connectionClosedStream => _connectionClosedController.stream;

  List<String> get connectedPeers =>
      _connections.entries.where((e) => e.value.isConnected).map((e) => e.key).toList();

  /// Все соединения (для доступа из SyncProtocol)
  Map<String, PeerConnection> get connections => Map.unmodifiable(_connections);

  int get connectionsCount => _connections.length;
  int get activeConnectionsCount =>
      _connections.values.where((c) => c.isConnected).length;

  P2PConnectionManager({this.listenPort = 9001});

  /// Запустить слушатель входящих соединений
  Future<bool> startListening() async {
    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        listenPort,
      );

      debugPrint('🎧 P2P слушатель запущен на порту $listenPort');

      _serverSocket!.listen(_handleIncomingConnection);

      return true;
    } catch (e) {
      debugPrint('❌ Ошибка запуска слушателя: $e');
      return false;
    }
  }

  /// Остановить слушатель
  Future<void> stopListening() async {
    await _serverSocket?.close();
    _serverSocket = null;

    // Закрываем все соединения
    for (final conn in _connections.values) {
      await conn.disconnect();
    }
    _connections.clear();

    debugPrint('🛑 P2P слушатель остановлен');
  }

  /// Подключиться к пиру
  Future<PeerConnection?> connectToPeer(String deviceId, String ip, int port) async {
    // Если соединение уже есть - возвращаем его
    if (_connections.containsKey(deviceId)) {
      final conn = _connections[deviceId]!;
      if (conn.isConnected) return conn;
    }

    final conn = PeerConnection(
      deviceId: deviceId,
      ip: ip,
      port: port,
    );

    _connections[deviceId] = conn;

    // Подписываемся на сообщения
    conn.messageStream.listen((message) {
      _messageController.add(message);
    });

    conn.stateStream.listen((state) {
      if (state == PeerConnectionState.connected) {
        _connectionOpenedController.add(deviceId);
      } else if (state == PeerConnectionState.disconnected ||
          state == PeerConnectionState.error) {
        _connectionClosedController.add(deviceId);
      }
    });

    final success = await conn.connect();
    return success ? conn : null;
  }

  /// Обработка входящего соединения
  void _handleIncomingConnection(Socket socket) {
    final remoteAddress = socket.remoteAddress;
    final remotePort = socket.remotePort;
    debugPrint('📥 Входящее P2P соединение от ${remoteAddress.address}:$remotePort');

    // Создаём временное соединение
    // deviceId будет определён позже из первого сообщения
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final conn = PeerConnection(
      deviceId: tempId,
      ip: remoteAddress.address,
      port: remotePort,
    );

    _connections[tempId] = conn;

    conn.messageStream.listen((message) {
      // Обновляем deviceId из первого сообщения
      if (message.payload?.containsKey('deviceId') == true) {
        final realDeviceId = message.payload!['deviceId'] as String;
        _connections.remove(tempId);
        _connections[realDeviceId] = conn;
      }
      _messageController.add(message);
    });

    conn.acceptConnection(socket);
  }

  /// Получить соединение по deviceId
  PeerConnection? getConnection(String deviceId) => _connections[deviceId];

  /// Отключиться от пира
  Future<void> disconnectFromPeer(String deviceId) async {
    final conn = _connections.remove(deviceId);
    await conn?.disconnect();
  }

  /// Отправить сообщение всем подключенным пирам
  void broadcast(P2PMessage message) {
    for (final conn in _connections.values) {
      if (conn.isConnected) {
        conn.sendMessage(message);
      }
    }
  }

  /// Закрыть все соединения
  Future<void> closeAll() async {
    await stopListening();
  }

  void dispose() {
    closeAll();
    _messageController.close();
    _connectionOpenedController.close();
    _connectionClosedController.close();
  }
}
