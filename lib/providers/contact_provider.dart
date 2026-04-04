import 'package:flutter/foundation.dart';
import '../models/contact_profile.dart';
import '../services/p2p/p2p.dart';

/// Провайдер для управления профилями контактов
/// Отвечает за хранение и получение контактной информации
class ContactProvider extends ChangeNotifier {
  final MapObjectStorage _storage;

  ContactProvider({
    required MapObjectStorage storage,
  }) : _storage = storage;

  /// Получить профиль контакта
  Future<ContactProfile?> getContactProfile(String userId) async {
    final json = await _storage.getContactProfile(userId);
    if (json == null) return null;

    // Конвертируем snake_case в camelCase
    final converted = <String, dynamic>{};
    json.forEach((key, value) {
      switch (key) {
        case 'user_id':
          converted['userId'] = value;
          break;
        case 'about':
          converted['about'] = value;
          break;
        case 'vk_link':
          converted['vkLink'] = value;
          break;
        case 'max_link':
          converted['maxLink'] = value;
          break;
        case 'visibility':
          converted['visibility'] = value;
          break;
        case 'accept_p2p_messages':
          converted['acceptP2PMessages'] = value == 1 || value == true;
          break;
        default:
          converted[key] = value;
      }
    });

    return ContactProfile.fromJson(converted);
  }

  /// Сохранить профиль контакта
  Future<void> saveContactProfile(ContactProfile profile) async {
    // Конвертируем camelCase в snake_case
    final json = <String, dynamic>{
      'user_id': profile.userId,
      'about': profile.about,
      'vk_link': profile.vkLink,
      'max_link': profile.maxLink,
      'visibility': profile.visibility.index,
      'accept_p2p_messages': profile.acceptP2PMessages ? 1 : 0,
    };

    await _storage.saveContactProfile(json);
    notifyListeners();
  }

  /// Проверить, можно ли показать контакт
  Future<bool> canShowContact({
    required String ownerId,
    required String viewerId,
    required String noteId,
    required Future<bool> Function(String noteId, String userId) hasInterest,
    required Future<List<NoteInterest>> Function(String noteId) getInterestsForNote,
  }) async {
    final profile = await getContactProfile(ownerId);
    if (profile == null) return false;

    // Владелец всегда видит свой контакт
    if (ownerId == viewerId) return true;

    // Проверяем настройки видимости
    switch (profile.visibility) {
      case ContactVisibility.afterApproval:
        // Проверяем, одобрен ли контакт
        final interests = await getInterestsForNote(noteId);
        final interest = interests.firstWhere(
          (i) => i.userId == viewerId,
          orElse: () => NoteInterest(noteId: '', userId: '', timestamp: DateTime.now()),
        );
        return interest.contactApproved;

      case ContactVisibility.afterInterest:
        // Проверяем, есть ли "Интересно"
        return await hasInterest(noteId, viewerId);

      case ContactVisibility.nobody:
        return false;
    }
  }

}
