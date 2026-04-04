import 'package:flutter/foundation.dart';
import '../models/map_objects/map_objects.dart';
import '../services/p2p/p2p.dart';

/// Провайдер для управления местами сбора (грибы, ягоды, орехи, травы)
/// Отвечает за создание, подтверждение и отметку сбора
class ForagingProvider extends ChangeNotifier {
  final MapObjectStorage _storage;

  /// Callback для трансляции обновлений через P2P
  Future<void> Function(MapObject object)? broadcastUpdate;

  /// Callback для обновления объекта в общем списке
  void Function(String id, MapObject updated)? updateObjectInList;

  /// Callback для получения списка всех объектов
  List<MapObject> Function()? getAllObjects;

  /// Callback для получения nearby объектов
  List<MapObject> Function()? getNearbyObjects;

  ForagingProvider({
    required MapObjectStorage storage,
    this.broadcastUpdate,
    this.updateObjectInList,
    this.getAllObjects,
    this.getNearbyObjects,
  }) : _storage = storage;

  /// Отметить сбор в месте
  Future<void> markHarvest(String spotId) async {
    final obj = await _storage.getObject(spotId);
    if (obj == null || obj is! ForagingSpot) return;

    final updated = obj.markHarvest();
    await _storage.updateObject(updated);
    await broadcastUpdate?.call(updated);
    updateObjectInList?.call(spotId, updated);
    notifyListeners();
  }

  /// Подтвердить место сбора
  Future<void> verifySpot(String spotId) async {
    final obj = await _storage.getObject(spotId);
    if (obj == null || obj is! ForagingSpot) return;

    final updated = obj.verify();
    await _storage.updateObject(updated);
    await broadcastUpdate?.call(updated);
    updateObjectInList?.call(spotId, updated);
    notifyListeners();
  }

  /// Получить места сбора рядом с пользователем
  List<ForagingSpot> getSpotsNearby() {
    final nearbyObjects = getNearbyObjects?.call() ?? [];
    return nearbyObjects
        .whereType<ForagingSpot>()
        .where((s) => !s.isDeleted)
        .toList();
  }

  /// Получить места сбора по категории
  List<ForagingSpot> getSpotsByCategory(ForagingCategory category) {
    final allObjects = getAllObjects?.call() ?? [];
    return allObjects
        .whereType<ForagingSpot>()
        .where((s) => s.category == category && !s.isDeleted)
        .toList();
  }

  /// Получить места сбора в сезон
  List<ForagingSpot> getSpotsInSeason() {
    final allObjects = getAllObjects?.call() ?? [];
    return allObjects
        .whereType<ForagingSpot>()
        .where((s) => s.isInSeason && !s.isDeleted)
        .toList();
  }

}
