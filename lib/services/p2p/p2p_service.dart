import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/map_objects/map_objects.dart';
import 'map_object_storage.dart';

/// Конфигурация P2P
class P2PConfig {
  final String signalingServer;
  final int signalingPort;
  final String zone;
  final String deviceId;
  final Duration syncInterval;

  const P2PConfig({
    required this.signalingServer,
    this.signalingPort = 9000,
    required this.zone,
    required this.deviceId,
    this.syncInterval = const Duration(seconds: 30),
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

/// P2P сервис (упрощённая версия для тестирования)
class P2PService {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  final MapObjectStorage _storage = MapObjectStorage();
  
  P2PConfig? _config;
  bool _isRunning = false;
  
  final StreamController<SyncResult> _syncController =
      StreamController<SyncResult>.broadcast();
  final StreamController<Peer> _peerController =
      StreamController<Peer>.broadcast();
  final StreamController<MapObject> _newObjectController =
      StreamController<MapObject>.broadcast();

  Stream<SyncResult> get syncStream => _syncController.stream;
  Stream<Peer> get peerStream => _peerController.stream;
  Stream<MapObject> get newObjectStream => _newObjectController.stream;

  /// Запуск P2P сервиса
  Future<void> start(P2PConfig config) async {
    if (_isRunning) {
      debugPrint('P2P сервис уже запущен');
      return;
    }

    _config = config;
    _isRunning = true;
    
    debugPrint('🚀 P2P сервис запущен (режим: локальный)');
    debugPrint('   Зона: ${config.zone}');
    debugPrint('   Устройство: ${config.deviceId}');
  }

  /// Остановка P2P сервиса
  Future<void> stop() async {
    _isRunning = false;
    debugPrint('🛑 P2P сервис остановлен');
  }

  /// Создание и рассылка объекта
  Future<void> createAndBroadcastObject(MapObject object) async {
    await _storage.saveObject(object);
    _newObjectController.add(object);
    debugPrint('📤 Объект сохранён: ${object.id}');
  }

  /// Принудительная синхронизация (заглушка)
  Future<void> forceSync() async {
    // В локальном режиме просто отправляем пустой результат
    _syncController.add(SyncResult(
      duration: Duration.zero,
    ));
  }

  /// Проверка активности
  bool get isRunning => _isRunning;

  void dispose() {
    _syncController.close();
    _peerController.close();
    _newObjectController.close();
  }
}
