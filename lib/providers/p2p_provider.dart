import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/map_objects/map_objects.dart';
import '../services/p2p/p2p.dart';

/// Провайдер для управления P2P соединением
/// Отвечает за синхронизацию объектов между устройствами
class P2PProvider extends ChangeNotifier {
  final P2PService _p2pService = P2PService();

  bool _isEnabled = true;
  String? _error;

  // Подписки
  StreamSubscription? _newObjectSubscription;
  StreamSubscription? _syncSubscription;

  /// Callback при получении нового объекта
  void Function(MapObject object)? onObjectReceived;

  /// Callback при синхронизации
  void Function(SyncResult result)? onSyncComplete;

  // Геттеры
  bool get isEnabled => _isEnabled;
  bool get isRunning => _p2pService.isRunning;
  String? get error => _error;

  /// Инициализация P2P
  Future<void> init({
    required void Function(MapObject object) onNewObject,
    required void Function(SyncResult result) onSync,
  }) async {
    onObjectReceived = onNewObject;
    onSyncComplete = onSync;

    // Подписываемся на новые объекты от P2P
    _newObjectSubscription = _p2pService.newObjectStream.listen((MapObject object) {
      onObjectReceived?.call(object);
    });

    // Подписываемся на результаты синхронизации
    _syncSubscription = _p2pService.syncStream.listen((result) {
      if (result.hasChanges) {
        debugPrint('🔄 Синхронизация: получено=${result.objectsReceived}, отправлено=${result.objectsSent}');
        onSyncComplete?.call(result);
      }
    });
  }

  /// Запуск P2P сервиса
  Future<void> start({
    required String signalingServer,
    required int signalingPort,
    required String deviceId,
    required double userLat,
    required double userLng,
  }) async {
    if (!_isEnabled) {
      debugPrint('⚠️ P2P не запущен: disabled');
      return;
    }

    try {
      final zone = MapObject.encodeGeohash(userLat, userLng, 6);

      final config = P2PConfig(
        signalingServer: signalingServer,
        signalingPort: signalingPort,
        zone: zone,
        deviceId: deviceId,
      );

      await _p2pService.start(config);
      debugPrint('✅ P2P запущен в зоне $zone');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Ошибка запуска P2P: $e');
      _error = 'Ошибка P2P: $e';
      notifyListeners();
    }
  }

  /// Остановка P2P сервиса
  Future<void> stop() async {
    await _p2pService.stop();
    debugPrint('🛑 P2P остановлен');
    notifyListeners();
  }

  /// Включить/выключить P2P
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled && _p2pService.isRunning) {
      stop();
    }
    notifyListeners();
  }

  /// Принудительная синхронизация
  Future<void> forceSync() async {
    await _p2pService.forceSync();
  }

  /// Трансляция объекта через P2P
  Future<void> broadcastObject(MapObject object) async {
    if (_isEnabled && _p2pService.isRunning) {
      await _p2pService.createAndBroadcastObject(object);
    }
  }

  @override
  void dispose() {
    _newObjectSubscription?.cancel();
    _syncSubscription?.cancel();
    _p2pService.dispose();
    super.dispose();
  }
}
