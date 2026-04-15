import 'package:flutter/foundation.dart';
import '../services/interest_notification_service.dart';
import '../di/service_locator.dart';

/// Провайдер для управления уведомлениями
/// Отвечает за уведомления о заинтересованности в заметках
class NotificationProvider extends ChangeNotifier {
  final InterestNotificationService _notificationService = getIt<InterestNotificationService>();

  bool _initialized = false;

  /// Инициализация
  Future<void> init() async {
    if (_initialized) return;
    await _notificationService.init();
    _initialized = true;
  }

  /// Получить непрочитанные уведомления
  Future<List<InterestNotification>> getUnreadNotifications() async {
    return await _notificationService.getUnreadNotifications();
  }

  /// Получить количество непрочитанных уведомлений
  Future<int> getUnreadCount() async {
    return await _notificationService.getUnreadCount();
  }

  /// Отметить уведомление как прочитанное
  Future<void> markAsRead(String notificationId) async {
    await _notificationService.markAsRead(notificationId);
    notifyListeners();
  }

  /// Stream уведомлений
  Stream<InterestNotification> get notificationStream => 
      _notificationService.notificationStream;

  /// Отправить уведомление автору о заинтересованности
  Future<void> notifyAuthorAboutInterest({
    required String noteId,
    required String noteTitle,
    required String authorId,
    required String interestedUserId,
    required String interestedUserName,
  }) async {
    await _notificationService.notifyAuthorAboutInterest(
      noteId: noteId,
      noteTitle: noteTitle,
      authorId: authorId,
      interestedUserId: interestedUserId,
      interestedUserName: interestedUserName,
    );
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }
}
