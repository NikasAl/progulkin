/// Signaling Server для P2P синхронизации
///
/// Это простой сигнальный сервер, который:
/// - Регистрирует устройства в географических зонах
/// - Сообщает устройствам о других устройствах в той же зоне
/// - Помогает с UDP Hole Punching для установки P2P соединений
///
/// НЕ хранит пользовательские данные (объекты карты)
///
/// Запуск: dart run bin/signaling_server.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SignalingServer {
  final int port;
  final bool verbose;

  ServerSocket? _server;
  final Map<String, _Client> _clients = {}; // deviceId -> Client
  final Map<String, Set<String>> _zones = {}; // zone -> Set<deviceId>
  final Map<String, String> _deviceToZone = {}; // deviceId -> zone

  SignalingServer({
    this.port = 9000,
    this.verbose = true,
  });

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);

    print('🚀 Signaling Server запущен на порту $port');
    print('📡 Ожидание подключений...');

    _server!.listen(_handleConnection);
  }

  void _handleConnection(Socket socket) {
    final client = _Client(socket);
    String? deviceId;

    socket.listen(
      (data) {
        try {
          final message = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
          deviceId = _handleMessage(client, message);
        } catch (e) {
          if (verbose) print('❌ Ошибка разбора сообщения: $e');
        }
      },
      onError: (error) {
        if (verbose) print('❌ Ошибка сокета: $error');
        _handleDisconnect(deviceId);
      },
      onDone: () {
        _handleDisconnect(deviceId);
      },
    );
  }

  String? _handleMessage(_Client client, Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final deviceId = message['deviceId'] as String?;
    final zone = message['zone'] as String?;

    switch (type) {
      case 'register':
        return _handleRegister(client, deviceId!, zone!, message);

      case 'leave':
        _handleDisconnect(deviceId);
        return null;

      case 'heartbeat':
        // Просто подтверждаем, что клиент жив
        return deviceId;

      case 'get_peers':
        _sendPeersList(deviceId!, zone!);
        return deviceId;

      default:
        if (verbose) print('❓ Неизвестный тип сообщения: $type');
        return deviceId;
    }
  }

  String _handleRegister(
    _Client client,
    String deviceId,
    String zone,
    Map<String, dynamic> message,
  ) {
    // Сохраняем информацию о клиенте
    client.deviceId = deviceId;
    client.zone = zone;
    client.port = message['port'] as int? ?? 9001;
    client.lastSeen = DateTime.now();

    // Определяем IP клиента
    final socket = client.socket;
    final remoteAddress = socket.remoteAddress;
    client.ip = remoteAddress.address;

    _clients[deviceId] = client;

    // Добавляем в зону
    _zones.putIfAbsent(zone, () => {});
    _zones[zone]!.add(deviceId);
    _deviceToZone[deviceId] = zone;

    if (verbose) {
      print('✅ Регистрация: $deviceId в зоне $zone (${client.ip}:${client.port})');
    }

    // Отправляем список пиров в этой зоне
    _sendPeersList(deviceId, zone);

    // Оповещаем других в зоне о новом пире
    _notifyPeerJoined(deviceId, zone, client);

    return deviceId;
  }

  void _sendPeersList(String deviceId, String zone) {
    final peers = <Map<String, dynamic>>[];
    final zonePeers = _zones[zone] ?? {};

    for (final peerId in zonePeers) {
      if (peerId != deviceId) {
        final peer = _clients[peerId];
        if (peer != null) {
          peers.add({
            'deviceId': peerId,
            'zone': zone,
            'ip': peer.ip,
            'port': peer.port,
          });
        }
      }
    }

    final client = _clients[deviceId];
    if (client != null) {
      _send(client, {
        'type': 'peers',
        'zone': zone,
        'peers': peers,
      });

      if (verbose) {
        print('📋 Отправлен список пиров для $deviceId: ${peers.length} пиров');
      }
    }
  }

  void _notifyPeerJoined(String newDeviceId, String zone, _Client newClient) {
    final zonePeers = _zones[zone] ?? {};

    for (final peerId in zonePeers) {
      if (peerId != newDeviceId) {
        final peer = _clients[peerId];
        if (peer != null) {
          _send(peer, {
            'type': 'peer_joined',
            'deviceId': newDeviceId,
            'zone': zone,
            'ip': newClient.ip,
            'port': newClient.port,
          });
        }
      }
    }
  }

  void _handleDisconnect(String? deviceId) {
    if (deviceId == null) return;

    final client = _clients[deviceId];
    final zone = _deviceToZone[deviceId];

    if (zone != null) {
      _zones[zone]?.remove(deviceId);

      // Оповещаем других об уходе
      final zonePeers = _zones[zone] ?? {};
      for (final peerId in zonePeers) {
        final peer = _clients[peerId];
        if (peer != null) {
          _send(peer, {
            'type': 'peer_left',
            'deviceId': deviceId,
            'zone': zone,
          });
        }
      }
    }

    _clients.remove(deviceId);
    _deviceToZone.remove(deviceId);

    client?.socket.destroy();

    if (verbose) {
      print('👋 Отключение: $deviceId');
    }
  }

  void _send(_Client client, Map<String, dynamic> message) {
    try {
      final data = utf8.encode(jsonEncode(message));
      client.socket.add(data);
    } catch (e) {
      if (verbose) print('❌ Ошибка отправки: $e');
    }
  }

  Future<void> stop() async {
    print('🛑 Остановка сервера...');

    for (final client in _clients.values) {
      client.socket.destroy();
    }

    _clients.clear();
    _zones.clear();
    _deviceToZone.clear();

    await _server?.close();
    print('✅ Сервер остановлен');
  }

  void printStats() {
    print('\n📊 Статистика сервера:');
    print('   Устройств: ${_clients.length}');
    print('   Зон: ${_zones.length}');

    for (final entry in _zones.entries) {
      print('   Зона ${entry.key}: ${entry.value.length} устройств');
    }
  }
}

class _Client {
  final Socket socket;
  String deviceId;
  String zone;
  String ip;
  int port;
  DateTime lastSeen;

  _Client(this.socket)
      : deviceId = '',
        zone = '',
        ip = '',
        port = 9001,
        lastSeen = DateTime.now();
}

/// Точка входа
Future<void> main(List<String> args) async {
  int port = 9000;
  bool verbose = true;

  // Парсинг аргументов
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--port' && i + 1 < args.length) {
      port = int.tryParse(args[i + 1]) ?? 9000;
    }
    if (args[i] == '--quiet') {
      verbose = false;
    }
  }

  final server = SignalingServer(port: port, verbose: verbose);

  // Обработка завершения
  ProcessSignal.sigint.watch().listen((_) {
    server.stop().then((_) => exit(0));
  });

  await server.start();

  // Периодический вывод статистики
  if (verbose) {
    Timer.periodic(const Duration(minutes: 5), (_) {
      server.printStats();
    });
  }
}
