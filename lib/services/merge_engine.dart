import 'package:flutter/foundation.dart';
import '../models/map_objects/map_objects.dart';

/// Стратегия разрешения конфликтов при мерже
enum MergeStrategy {
  localWins,    // Локальная версия важнее
  remoteWins,   // Входящая версия важнее
  newerWins,    // Тот, кто новее (по updatedAt)
  mergeBoth,    // Попытаться объединить (для счётчиков)
  askUser,      // Требуется решение пользователя
}

/// Тип конфликта при мерже
enum ConflictType {
  bothModified,       // Обе стороны изменили объект
  localDeletedRemoteModified,  // Локально удалён, удалённо изменён
  localModifiedRemoteDeleted,  // Локально изменён, удалённо удалён
  bothDeleted,        // Обе стороны удалили
  versionMismatch,    // Несовпадение версий при одинаковой дате
}

/// Описание конфликта
class MergeConflict {
  final String objectId;
  final ConflictType type;
  final MapObject localObject;
  final MapObject remoteObject;
  final String description;

  MergeConflict({
    required this.objectId,
    required this.type,
    required this.localObject,
    required this.remoteObject,
    required this.description,
  });

  /// Получить описание конфликта для UI
  String get userDescription {
    switch (type) {
      case ConflictType.bothModified:
        return 'Объект "${localObject.shortDescription}" изменён в обоих экземплярах';
      case ConflictType.localDeletedRemoteModified:
        return 'Объект "${remoteObject.shortDescription}" удалён локально, но изменён удалённо';
      case ConflictType.localModifiedRemoteDeleted:
        return 'Объект "${localObject.shortDescription}" изменён локально, но удалён удалённо';
      case ConflictType.bothDeleted:
        return 'Объект "${localObject.shortDescription}" удалён в обоих экземплярах';
      case ConflictType.versionMismatch:
        return 'Версии объекта "${localObject.shortDescription}" не совпадают';
    }
  }
}

/// Результат мержа
class MergeResult {
  final int added;
  final int updated;
  final int deleted;
  final int skipped;
  final int conflicts;
  final List<MergeConflict> conflictList;
  final List<String> addedObjects;
  final List<String> updatedObjects;
  final List<String> deletedObjects;

  MergeResult({
    this.added = 0,
    this.updated = 0,
    this.deleted = 0,
    this.skipped = 0,
    this.conflicts = 0,
    this.conflictList = const [],
    this.addedObjects = const [],
    this.updatedObjects = const [],
    this.deletedObjects = const [],
  });

  String get summary {
    final parts = <String>[];
    if (added > 0) parts.add('добавлено: $added');
    if (updated > 0) parts.add('обновлено: $updated');
    if (deleted > 0) parts.add('удалено: $deleted');
    if (skipped > 0) parts.add('пропущено: $skipped');
    if (conflicts > 0) parts.add('конфликтов: $conflicts');
    return parts.join(', ');
  }

  MergeResult copyWith({
    int? added,
    int? updated,
    int? deleted,
    int? skipped,
    int? conflicts,
    List<MergeConflict>? conflictList,
    List<String>? addedObjects,
    List<String>? updatedObjects,
    List<String>? deletedObjects,
  }) {
    return MergeResult(
      added: added ?? this.added,
      updated: updated ?? this.updated,
      deleted: deleted ?? this.deleted,
      skipped: skipped ?? this.skipped,
      conflicts: conflicts ?? this.conflicts,
      conflictList: conflictList ?? this.conflictList,
      addedObjects: addedObjects ?? this.addedObjects,
      updatedObjects: updatedObjects ?? this.updatedObjects,
      deletedObjects: deletedObjects ?? this.deletedObjects,
    );
  }
}

/// Движок мержа объектов карты
class MergeEngine {
  /// Стратегия по умолчанию
  MergeStrategy defaultStrategy = MergeStrategy.newerWins;

  /// Выполнить мерж списков объектов
  /// Возвращает результат мержа со списком конфликтов
  Future<MergeResult> merge({
    required List<MapObject> localObjects,
    required List<MapObject> remoteObjects,
    MergeStrategy strategy = MergeStrategy.newerWins,
    Set<String>? resolvedConflicts, // ID объектов с разрешёнными конфликтами
  }) async {
    final result = MergeResult();
    final conflicts = <MergeConflict>[];
    final addedObjects = <String>[];
    final updatedObjects = <String>[];
    final deletedObjects = <String>[];

    int added = 0;
    int updated = 0;
    int deleted = 0;
    int skipped = 0;

    // Создаём карту локальных объектов по ID
    final localMap = <String, MapObject>{};
    for (final obj in localObjects) {
      localMap[obj.id] = obj;
    }

    // Обрабатываем каждый удалённый объект
    for (final remote in remoteObjects) {
      final local = localMap[remote.id];

      if (local == null) {
        // Объект существует только удалённо
        if (remote.isDeleted) {
          // Удалённый объект - пропускаем
          skipped++;
        } else {
          // Новый объект - добавляем
          added++;
          addedObjects.add('${remote.type.emoji} ${remote.shortDescription}');
        }
        continue;
      }

      // Объект существует в обоих местах
      final conflict = _detectConflict(local, remote);

      if (conflict != null) {
        // Есть конфликт
        if (resolvedConflicts?.contains(remote.id) == true) {
          // Конфликт уже разрешён пользователем - пропускаем
          skipped++;
        } else {
          conflicts.add(conflict);
        }
        continue;
      }

      // Конфликта нет - применяем стратегию
      final resolved = _resolveMerge(local, remote, strategy);

      if (resolved != null) {
        if (resolved.isDeleted && !local.isDeleted) {
          deleted++;
          deletedObjects.add('${resolved.type.emoji} ${resolved.shortDescription}');
        } else if (!resolved.isDeleted) {
          updated++;
          updatedObjects.add('${resolved.type.emoji} ${resolved.shortDescription}');
        }
      } else {
        skipped++;
      }
    }

    debugPrint('🔄 Merge завершён: added=$added, updated=$updated, deleted=$deleted, skipped=$skipped, conflicts=${conflicts.length}');

    return result.copyWith(
      added: added,
      updated: updated,
      deleted: deleted,
      skipped: skipped,
      conflicts: conflicts.length,
      conflictList: conflicts,
      addedObjects: addedObjects,
      updatedObjects: updatedObjects,
      deletedObjects: deletedObjects,
    );
  }

  /// Детекция конфликта между локальным и удалённым объектами
  MergeConflict? _detectConflict(MapObject local, MapObject remote) {
    final localDeleted = local.isDeleted;
    final remoteDeleted = remote.isDeleted;

    // Оба удалены - нет конфликта
    if (localDeleted && remoteDeleted) {
      return null;
    }

    // Локальный удалён, удалённый нет
    if (localDeleted && !remoteDeleted) {
      // Проверяем, был ли удалённый изменён после локального удаления
      if (remote.updatedAt.isAfter(local.deletedAt!)) {
        return MergeConflict(
          objectId: local.id,
          type: ConflictType.localDeletedRemoteModified,
          localObject: local,
          remoteObject: remote,
          description: 'Локально удалён, удалённо изменён',
        );
      }
      // Удаление новее - оставляем удаление
      return null;
    }

    // Локальный не удалён, удалённый удалён
    if (!localDeleted && remoteDeleted) {
      // Проверяем, был ли локальный изменён после удалённого удаления
      if (local.updatedAt.isAfter(remote.deletedAt!)) {
        return MergeConflict(
          objectId: local.id,
          type: ConflictType.localModifiedRemoteDeleted,
          localObject: local,
          remoteObject: remote,
          description: 'Локально изменён, удалённо удалён',
        );
      }
      // Удаление новее - применяем удаление
      return null;
    }

    // Оба не удалены - проверяем изменения
    final localTime = local.updatedAt;
    final remoteTime = remote.updatedAt;
    final timeDiff = localTime.difference(remoteTime).abs();

    // Если времена обновления совпадают (в пределах 1 секунды)
    if (timeDiff.inSeconds <= 1) {
      // Проверяем версии
      if (local.version != remote.version) {
        return MergeConflict(
          objectId: local.id,
          type: ConflictType.versionMismatch,
          localObject: local,
          remoteObject: remote,
          description: 'Несовпадение версий при одинаковой дате',
        );
      }
      // Версии совпадают - нет изменений
      return null;
    }

    // Оба изменены
    // Считаем конфликтом, если изменения в пределах 5 минут
    if (timeDiff.inMinutes <= 5) {
      return MergeConflict(
        objectId: local.id,
        type: ConflictType.bothModified,
        localObject: local,
        remoteObject: remote,
        description: 'Объект изменён в обоих экземплярах',
      );
    }

    // Изменения в разное время - конфликта нет, новее выигрывает
    return null;
  }

  /// Разрешить мерж согласно стратегии
  MapObject? _resolveMerge(MapObject local, MapObject remote, MergeStrategy strategy) {
    switch (strategy) {
      case MergeStrategy.localWins:
        return local;

      case MergeStrategy.remoteWins:
        return remote;

      case MergeStrategy.newerWins:
        // Тот, у кого updatedAt новее
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          return remote;
        } else if (local.updatedAt.isAfter(remote.updatedAt)) {
          return local;
        }
        // Времена равны - сравниваем версии
        if (remote.version > local.version) {
          return remote;
        }
        return local;

      case MergeStrategy.mergeBoth:
        // Попытка умного мержа
        return _smartMerge(local, remote);

      case MergeStrategy.askUser:
        // Это обрабатывается на уровне UI
        return null;
    }
  }

  /// Умный мерж - объединение данных
  MapObject _smartMerge(MapObject local, MapObject remote) {
    // Берем более новую версию как базу
    MapObject base = remote.updatedAt.isAfter(local.updatedAt) ? remote : local;
    MapObject other = remote.updatedAt.isAfter(local.updatedAt) ? local : remote;

    // Для счётчиков (confirms, denies, views) берём максимальные значения
    // Это актуально для TrashMonster и других объектов с подтверждениями

    // Если оба объекта одного типа - пытаемся объединить специфичные поля
    if (base is TrashMonster && other is TrashMonster) {
      return TrashMonster(
        id: base.id,
        latitude: base.latitude,
        longitude: base.longitude,
        ownerId: base.ownerId,
        ownerName: base.ownerName,
        ownerReputation: base.ownerReputation,
        createdAt: base.createdAt,
        updatedAt: DateTime.now(),
        expiresAt: base.expiresAt,
        deletedAt: base.deletedAt,
        trashType: base.trashType,
        quantity: base.quantity,
        monsterClass: base.monsterClass,
        description: base.description,
        photoIds: _mergeLists(base.photoIds, other.photoIds),
        isCleaned: base.isCleaned || other.isCleaned, // Если убран где-то - считаем убранным
        cleanedBy: base.cleanedBy ?? other.cleanedBy,
        cleanedAt: base.cleanedAt ?? other.cleanedAt,
        status: base.isCleaned ? MapObjectStatus.cleaned : base.status,
        confirms: _max(base.confirms, other.confirms),
        denies: _max(base.denies, other.denies),
        views: _max(base.views, other.views),
        version: _max(base.version, other.version) + 1,
      );
    }

    // Для других типов - берём новее и обновляем счётчики
    // Возвращаем базовый объект (приведение не идеально, но работает для базовых полей)
    return base;
  }

  /// Объединить списки (для photoIds и т.п.)
  List<String> _mergeLists(List<String> a, List<String> b) {
    return [...{...a, ...b}];
  }

  /// Максимум из двух чисел
  int _max(int a, int b) => a > b ? a : b;

  /// Разрешить конкретный конфликт
  MapObject resolveConflict(MergeConflict conflict, MergeStrategy strategy) {
    switch (strategy) {
      case MergeStrategy.localWins:
        return conflict.localObject;
      case MergeStrategy.remoteWins:
        return conflict.remoteObject;
      case MergeStrategy.newerWins:
        return conflict.remoteObject.updatedAt.isAfter(conflict.localObject.updatedAt)
            ? conflict.remoteObject
            : conflict.localObject;
      case MergeStrategy.mergeBoth:
        return _smartMerge(conflict.localObject, conflict.remoteObject);
      case MergeStrategy.askUser:
        throw StateError('askUser strategy requires user interaction');
    }
  }

  /// Проверить, нужен ли мерж (есть ли различия)
  bool needsMerge(List<MapObject> local, List<MapObject> remote) {
    if (local.length != remote.length) return true;

    final localMap = <String, MapObject>{};
    for (final obj in local) {
      localMap[obj.id] = obj;
    }

    for (final remoteObj in remote) {
      final localObj = localMap[remoteObj.id];
      if (localObj == null) return true;

      if (localObj.updatedAt != remoteObj.updatedAt ||
          localObj.version != remoteObj.version ||
          localObj.isDeleted != remoteObj.isDeleted) {
        return true;
      }
    }

    return false;
  }
}
