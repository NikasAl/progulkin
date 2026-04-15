import 'package:flutter/foundation.dart';
import '../models/map_objects/map_objects.dart';
import '../services/p2p/p2p.dart';

/// Провайдер для модерации объектов и фото
/// Отвечает за подтверждение/опровержение объектов и голосование за фото
class ModerationProvider extends ChangeNotifier {
  final MapObjectStorage _storage;

  /// Callback для трансляции обновлений через P2P
  Future<void> Function(MapObject object)? broadcastUpdate;

  /// Callback для обновления объекта в общем списке
  void Function(String id, MapObject updated)? updateObjectInList;

  /// Callback для обновления nearby списка
  void Function()? updateNearbyObjects;

  ModerationProvider({
    required MapObjectStorage storage,
    this.broadcastUpdate,
    this.updateObjectInList,
    this.updateNearbyObjects,
  }) : _storage = storage;

  /// Подтвердить объект
  Future<void> confirmObject(String objectId) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null) return;

    obj.confirms++;
    obj.incrementVersion();

    await _storage.updateObject(obj);
    await broadcastUpdate?.call(obj);
    updateObjectInList?.call(objectId, obj);
    updateNearbyObjects?.call();
    notifyListeners();
  }

  /// Опровергнуть объект
  Future<void> denyObject(String objectId) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null) return;

    obj.denies++;
    obj.incrementVersion();

    // Автоскрытие при большом количестве жалоб
    if (obj.shouldBeHidden) {
      obj.status = MapObjectStatus.hidden;
    }

    await _storage.updateObject(obj);
    await broadcastUpdate?.call(obj);
    updateObjectInList?.call(objectId, obj);
    updateNearbyObjects?.call();
    notifyListeners();
  }

  /// Отметить монстра как убранного
  Future<void> cleanTrashMonster(String objectId, String userId) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null || obj is! TrashMonster) return;

    final cleaned = obj.markAsCleaned(userId);
    await _storage.updateObject(cleaned);
    await broadcastUpdate?.call(cleaned);
    updateObjectInList?.call(objectId, cleaned);
    updateNearbyObjects?.call();
    notifyListeners();
  }

  // ==================== Модерация фото ====================

  /// Проголосовать за фото (подтвердить)
  Future<void> confirmPhoto(String photoId, String userId) async {
    await _storage.votePhoto(photoId: photoId, userId: userId, vote: 1);
    notifyListeners();
  }

  /// Пожаловаться на фото
  Future<void> complainPhoto(String photoId, String userId) async {
    await _storage.votePhoto(photoId: photoId, userId: userId, vote: -1);
    notifyListeners();
  }

  /// Получить статистику голосов за фото
  Future<Map<String, int>> getPhotoVoteStats(String photoId) async {
    return await _storage.getPhotoVoteStats(photoId);
  }

  /// Получить голос пользователя за фото
  Future<int?> getUserPhotoVote(String photoId, String userId) async {
    return await _storage.getUserPhotoVote(photoId, userId);
  }

  /// Получить фото на модерации
  Future<List<Map<String, dynamic>>> getPhotosForModeration() async {
    return await _storage.getPhotosForModeration();
  }

}
