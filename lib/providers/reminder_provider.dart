import 'package:flutter/foundation.dart';
import '../models/map_objects/map_objects.dart';
import '../services/p2p/p2p.dart';

/// Провайдер для управления напоминаниями
/// Отвечает за создание, активацию и отложение напоминаний
class ReminderProvider extends ChangeNotifier {
  final MapObjectStorage _storage;

  /// Callback для трансляции обновлений через P2P
  Future<void> Function(MapObject object)? broadcastUpdate;

  /// Callback для обновления объекта в общем списке
  void Function(String id, MapObject updated)? updateObjectInList;

  /// Callback для получения списка всех объектов
  List<MapObject> Function()? getAllObjects;

  ReminderProvider({
    required MapObjectStorage storage,
    this.broadcastUpdate,
    this.updateObjectInList,
    this.getAllObjects,
  }) : _storage = storage;

  /// Активировать напоминание
  Future<void> activateReminder(String reminderId) async {
    final obj = await _storage.getObject(reminderId);
    if (obj == null || obj is! ReminderCharacter) return;

    final activated = obj.activate();
    await _storage.updateObject(activated);
    await broadcastUpdate?.call(activated);
    updateObjectInList?.call(reminderId, activated);
    notifyListeners();
  }

  /// Деактивировать напоминание
  Future<void> deactivateReminder(String reminderId) async {
    final obj = await _storage.getObject(reminderId);
    if (obj == null || obj is! ReminderCharacter) return;

    final deactivated = obj.deactivate();
    await _storage.updateObject(deactivated);
    await broadcastUpdate?.call(deactivated);
    updateObjectInList?.call(reminderId, deactivated);
    notifyListeners();
  }

  /// Отложить напоминание
  Future<void> snoozeReminder(String reminderId, Duration duration) async {
    final obj = await _storage.getObject(reminderId);
    if (obj == null || obj is! ReminderCharacter) return;

    final snoozed = obj.snooze(duration);
    await _storage.updateObject(snoozed);
    await broadcastUpdate?.call(snoozed);
    updateObjectInList?.call(reminderId, snoozed);
    notifyListeners();
  }

  /// Получить напоминания пользователя
  List<ReminderCharacter> getUserReminders(String userId) {
    final allObjects = getAllObjects?.call() ?? [];
    return allObjects
        .whereType<ReminderCharacter>()
        .where((r) => r.ownerId == userId)
        .toList();
  }

  /// Получить активные напоминания пользователя
  List<ReminderCharacter> getActiveReminders(String userId) {
    final allObjects = getAllObjects?.call() ?? [];
    return allObjects
        .whereType<ReminderCharacter>()
        .where((r) => r.ownerId == userId && r.isActive)
        .toList();
  }

}
