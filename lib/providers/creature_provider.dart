import 'package:flutter/foundation.dart';
import '../models/map_objects/map_objects.dart';
import '../services/p2p/p2p.dart';
import '../services/creature_service.dart';

/// Провайдер для управления существами
/// Отвечает за спавн, поимку и коллекцию существ
class CreatureProvider extends ChangeNotifier {
  final MapObjectStorage _storage;
  final CreatureService _creatureService = CreatureService();

  /// Callback для трансляции обновлений через P2P
  Future<void> Function(MapObject object)? broadcastUpdate;

  /// Callback для получения текущего списка всех объектов
  List<MapObject> Function()? getAllObjects;

  /// Callback для обновления объекта в общем списке
  void Function(String id, MapObject updated)? updateObjectInList;

  CreatureProvider({
    required MapObjectStorage storage,
    this.broadcastUpdate,
    this.getAllObjects,
    this.updateObjectInList,
  }) : _storage = storage;

  /// Заспавнить существо
  Future<Creature> spawnCreature({
    required String id,
    required double latitude,
    required double longitude,
    required CreatureType creatureType,
    required CreatureRarity rarity,
    required CreatureHabitat habitat,
    int lifetimeMinutes = 60,
  }) async {
    final creature = Creature.spawnWild(
      id: id,
      latitude: latitude,
      longitude: longitude,
      creatureType: creatureType,
      rarity: rarity,
      habitat: habitat,
      lifetimeMinutes: lifetimeMinutes,
    );

    await _storage.saveObject(creature);
    await broadcastUpdate?.call(creature);
    notifyListeners();
    return creature;
  }

  /// Спавн существ вокруг игрока
  Future<List<Creature>> spawnCreaturesAroundPlayer({
    required String Function() generateId,
    required double playerLat,
    required double playerLng,
    int maxCreatures = 2,
    double radiusKm = 1.5,
  }) async {
    // Используем асинхронную версию с определением среды через OSM
    final spawned = await _creatureService.spawnAroundPlayerAsync(
      playerLat: playerLat,
      playerLng: playerLng,
      maxCreatures: maxCreatures,
      radiusKm: radiusKm,
    );

    for (final creature in spawned) {
      await _storage.saveObject(creature);
      await broadcastUpdate?.call(creature);
    }

    notifyListeners();
    return spawned;
  }

  /// Попытка поимки существа с расчётом шанса
  Future<CatchResult> attemptCatchCreature({
    required String creatureId,
    required String userId,
    required String userName,
    required int playerLevel,
    double? userLat,
    double? userLng,
  }) async {
    final obj = await _storage.getObject(creatureId);
    if (obj == null || obj is! Creature) {
      return CatchResult.failed(
        creature: Creature.spawnWild(
          id: '',
          latitude: 0,
          longitude: 0,
          creatureType: CreatureType.domovoy,
          rarity: CreatureRarity.common,
          habitat: CreatureHabitat.anywhere,
        ),
        chance: 0,
      );
    }

    // Существо уже поймано
    if (!obj.isWild) {
      return CatchResult.failed(
        creature: obj,
        chance: 0,
        escaped: false,
      );
    }

    // Проверка расстояния (25 метров максимум)
    if (userLat != null && userLng != null) {
      final distance = calculateDistance(
        userLat, userLng,
        obj.latitude, obj.longitude,
      );
      if (distance > 25) {
        return CatchResult.failed(
          creature: obj,
          chance: 0,
          escaped: false,
        );
      }
    }

    final result = _creatureService.tryCatchCreature(obj, playerLevel);

    if (result.isSuccess) {
      final caught = obj.catchCreature(userId, userName);
      await _storage.updateObject(caught);
      await broadcastUpdate?.call(caught);
      updateObjectInList?.call(creatureId, caught);
      notifyListeners();
    }

    return result;
  }

  /// Поймать существо (простая версия без проверки шанса)
  Future<bool> catchCreature(
    String objectId,
    String userId,
    String userName, {
    double? userLat,
    double? userLng,
  }) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null || obj is! Creature) return false;

    // Проверка расстояния (25 метров максимум)
    if (userLat != null && userLng != null) {
      final distance = calculateDistance(
        userLat, userLng,
        obj.latitude, obj.longitude,
      );
      if (distance > 25) {
        debugPrint('⚠️ Попытка поймать существо с расстояния ${distance.toInt()}м');
        return false;
      }
    }

    final caught = obj.catchCreature(userId, userName);
    await _storage.updateObject(caught);
    await broadcastUpdate?.call(caught);
    updateObjectInList?.call(objectId, caught);
    notifyListeners();
    return true;
  }

  /// Получить коллекцию пойманных существ пользователя
  List<Creature> getUserCreatureCollection(String userId) {
    final allObjects = getAllObjects?.call() ?? [];
    return allObjects
        .whereType<Creature>()
        .where((c) => c.caughtBy == userId)
        .toList();
  }

  /// Получить диких существ рядом с игроком
  List<Creature> getWildCreaturesNearby(List<MapObject> nearbyObjects) {
    return nearbyObjects
        .whereType<Creature>()
        .where((c) => c.isWild && c.isAlive)
        .toList();
  }

  /// Получить статистику коллекции существ
  Map<String, dynamic> getCreatureCollectionStats(String userId) {
    final collection = getUserCreatureCollection(userId);

    final byRarity = <CreatureRarity, int>{};
    for (final rarity in CreatureRarity.values) {
      byRarity[rarity] = collection.where((c) => c.rarity == rarity).length;
    }

    final byType = <CreatureType, int>{};
    for (final creature in collection) {
      byType[creature.creatureType] = (byType[creature.creatureType] ?? 0) + 1;
    }

    return {
      'total': collection.length,
      'byRarity': byRarity,
      'byType': byType,
      'totalPoints': collection.fold(0, (sum, c) => sum + c.catchPoints),
    };
  }

  /// Очистить истёкших диких существ из базы данных
  Future<int> cleanExpiredWildCreatures(List<MapObject> objects) async {
    int removed = 0;
    final toRemove = <String>[];

    for (final obj in objects) {
      if (obj.type == MapObjectType.creature) {
        final creature = obj as Creature;
        // Удаляем только диких истёкших существ
        if (creature.isWild && creature.isExpired) {
          toRemove.add(creature.id);
          removed++;
        }
      }
    }

    if (removed > 0) {
      debugPrint('🧹 Очистка: удалено $removed истёкших диких существ');
      for (final id in toRemove) {
        await _storage.deleteObject(id);
      }
      notifyListeners();
    }

    return removed;
  }

  /// Уведомить об изменении объектов (вызывается извне при обновлении MapObjectProvider)
  void notifyObjectsChanged() {
    notifyListeners();
  }

  /// Очистить всех диких существ (при завершении прогулки)
  Future<int> cleanAllWildCreatures(List<MapObject> objects) async {
    int removed = 0;
    final toRemove = <String>[];

    for (final obj in objects) {
      if (obj.type == MapObjectType.creature) {
        final creature = obj as Creature;
        // Удаляем диких существ
        if (creature.isWild) {
          toRemove.add(creature.id);
          removed++;
        }
      }
    }

    if (removed > 0) {
      debugPrint('🧹 Очистка после прогулки: удалено $removed диких существ');
      for (final id in toRemove) {
        await _storage.deleteObject(id);
      }
      notifyListeners();
    }

    return removed;
  }
}
