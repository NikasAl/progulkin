import 'package:flutter/foundation.dart';
import '../models/map_objects/map_objects.dart';
import '../models/contact_profile.dart'; // Для NoteInterest
import '../services/p2p/p2p.dart';

/// Провайдер для управления интересами к заметкам
/// Отвечает за отметки "Интересно" и запросы контактов
class InterestProvider extends ChangeNotifier {
  final MapObjectStorage _storage;

  /// Callback для трансляции обновлений через P2P
  Future<void> Function(MapObject object)? broadcastUpdate;

  /// Callback для обновления объекта в общем списке
  void Function(String id, MapObject updated)? updateObjectInList;

  /// Callback для отправки уведомления автору
  Future<void> Function({
    required String noteId,
    required String noteTitle,
    required String authorId,
    required String interestedUserId,
    required String interestedUserName,
  })? notifyAuthorAboutInterest;

  InterestProvider({
    required MapObjectStorage storage,
    this.broadcastUpdate,
    this.updateObjectInList,
    this.notifyAuthorAboutInterest,
  }) : _storage = storage;

  /// Добавить "Интересно" к заметке
  Future<void> addInterestToNote(String noteId, String userId) async {
    await _storage.addInterest(noteId: noteId, userId: userId);

    final obj = await _storage.getObject(noteId);
    if (obj == null || obj is! InterestNote) return;

    final updated = obj.addInterest(userId);
    await _storage.updateObject(updated);
    await broadcastUpdate?.call(updated);

    // Отправляем уведомление автору
    await notifyAuthorAboutInterest?.call(
      noteId: noteId,
      noteTitle: updated.title,
      authorId: updated.ownerId,
      interestedUserId: userId,
      interestedUserName: 'Кто-то', // TODO: Получить имя пользователя
    );

    // Обновляем локальный список
    updateObjectInList?.call(noteId, updated);

    notifyListeners();
  }

  /// Убрать "Интересно" с заметки
  Future<void> removeInterestFromNote(String noteId, String userId) async {
    await _storage.removeInterest(noteId, userId);

    final obj = await _storage.getObject(noteId);
    if (obj == null || obj is! InterestNote) return;

    final updated = obj.removeInterest(userId);
    await _storage.updateObject(updated);
    await broadcastUpdate?.call(updated);

    // Обновляем локальный список
    updateObjectInList?.call(noteId, updated);

    notifyListeners();
  }

  /// Получить список пользователей, отметивших "Интересно"
  Future<List<NoteInterest>> getInterestsForNote(String noteId) async {
    final results = await _storage.getInterestsForNote(noteId);
    return results.map((json) => NoteInterest.fromJson(json)).toList();
  }

  /// Проверил ли пользователь "Интересно" на заметке
  Future<bool> hasInterest(String noteId, String userId) async {
    final interests = await getInterestsForNote(noteId);
    return interests.any((i) => i.userId == userId);
  }

  /// Запросить контакт у автора заметки
  Future<void> requestContact(String noteId, String userId) async {
    await _storage.addInterest(
      noteId: noteId,
      userId: userId,
      contactRequestSent: true,
    );

    // TODO: Отправить P2P уведомление автору
  }

  /// Одобрить запрос на контакт
  Future<void> approveContactRequest(String noteId, String userId) async {
    await _storage.addInterest(
      noteId: noteId,
      userId: userId,
      contactRequestSent: true,
      contactApproved: true,
    );
  }

}
