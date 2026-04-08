import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import 'p2p/map_object_storage.dart';

/// Сервис уведомлений о "Интересно"
/// Отправляет push-уведомления авторам заметок когда кто-то отмечает "Интересно"
class InterestNotificationService {
  static final InterestNotificationService _instance = InterestNotificationService._internal();
  factory InterestNotificationService() => _instance;
  InterestNotificationService._internal();

  final MapObjectStorage _storage = MapObjectStorage();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final Uuid _uuid = const Uuid();

  bool _initialized = false;
  final StreamController<InterestNotification> _notificationController =
      StreamController<InterestNotification>.broadcast();

  Stream<InterestNotification> get notificationStream => _notificationController.stream;

  /// Инициализация сервиса
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    debugPrint('✅ InterestNotificationService инициализирован');
  }

  /// Обработка нажатия на уведомление
  void _onNotificationTapped(NotificationResponse response) {
    // Можно добавить навигацию к заметке
    debugPrint('📬 Уведомление нажато: ${response.payload}');
  }

  /// Отправить уведомление автору заметки о новом "Интересно"
  Future<void> notifyAuthorAboutInterest({
    required String noteId,
    required String noteTitle,
    required String authorId,
    required String interestedUserId,
    required String interestedUserName,
  }) async {
    // Не отправляем уведомление самому себе
    if (authorId == interestedUserId) return;

    final notificationId = _uuid.v4();

    // Сохраняем уведомление в базу
    await _storage.saveNotification(
      id: notificationId,
      type: 'interest',
      title: 'Кому-то интересно ваше место!',
      body: '$interestedUserName отметили «Интересно» на вашей заметке "$noteTitle"',
      data: {
        'noteId': noteId,
        'interestedUserId': interestedUserId,
        'interestedUserName': interestedUserName,
      },
    );

    // Создаём объект уведомления
    final notification = InterestNotification(
      id: notificationId,
      type: 'interest',
      title: 'Кому-то интересно ваше место!',
      body: '$interestedUserName отметили «Интересно» на вашей заметке "$noteTitle"',
      noteId: noteId,
      interestedUserId: interestedUserId,
      interestedUserName: interestedUserName,
      timestamp: DateTime.now(),
    );

    // Отправляем в стрим
    _notificationController.add(notification);

    // Показываем push-уведомление
    await _showPushNotification(notification);

    debugPrint('📬 Уведомление отправлено автору $authorId о "Интересно" от $interestedUserName');
  }

  /// Показать push-уведомление
  Future<void> _showPushNotification(InterestNotification notification) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'interests',
      'Интересы',
      channelDescription: 'Уведомления о том, что кому-то интересны ваши места',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/splash_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      notification.id.hashCode,
      notification.title,
      notification.body,
      details,
      payload: notification.noteId,
    );
  }

  /// Получить непрочитанные уведомления
  Future<List<InterestNotification>> getUnreadNotifications() async {
    final results = await _storage.getUnreadNotifications();

    return results.map((json) {
      return InterestNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        noteId: json['data'] != null
            ? (json['data'] as Map<String, dynamic>)['noteId'] as String? ?? ''
            : '',
        interestedUserId: json['data'] != null
            ? (json['data'] as Map<String, dynamic>)['interestedUserId'] as String? ?? ''
            : '',
        interestedUserName: json['data'] != null
            ? (json['data'] as Map<String, dynamic>)['interestedUserName'] as String? ?? ''
            : '',
        timestamp: DateTime.parse(json['created_at'] as String),
      );
    }).toList();
  }

  /// Получить количество непрочитанных уведомлений
  Future<int> getUnreadCount() async {
    return await _storage.getUnreadNotificationCount();
  }

  /// Отметить уведомление как прочитанное
  Future<void> markAsRead(String notificationId) async {
    await _storage.markNotificationRead(notificationId);
  }

  /// Отправить уведомление о подтверждении контакта
  Future<void> notifyContactApproved({
    required String noteId,
    required String noteTitle,
    required String authorId,
    required String approvedUserId,
    required String approvedUserName,
  }) async {
    final notificationId = _uuid.v4();

    await _storage.saveNotification(
      id: notificationId,
      type: 'contact_approved',
      title: 'Контакт одобрен!',
      body: '$approvedUserName одобрил ваш запрос на контакт по заметке "$noteTitle"',
      data: {
        'noteId': noteId,
        'approvedUserId': approvedUserId,
        'approvedUserName': approvedUserName,
      },
    );

    final notification = InterestNotification(
      id: notificationId,
      type: 'contact_approved',
      title: 'Контакт одобрен!',
      body: '$approvedUserName одобрил ваш запрос на контакт по заметке "$noteTitle"',
      noteId: noteId,
      interestedUserId: approvedUserId,
      interestedUserName: approvedUserName,
      timestamp: DateTime.now(),
    );

    _notificationController.add(notification);
    await _showPushNotification(notification);
  }

  /// Отправить уведомление о жалобе на фото (для модераторов/автора)
  Future<void> notifyPhotoComplaint({
    required String photoId,
    required String objectId,
    required String objectTitle,
    required String reporterId,
    int complaintCount = 1,
  }) async {
    final notificationId = _uuid.v4();

    await _storage.saveNotification(
      id: notificationId,
      type: 'photo_complaint',
      title: 'Жалоба на фото',
      body: 'Получена $complaintCount-я жалоба на фото в "$objectTitle"',
      data: {
        'photoId': photoId,
        'objectId': objectId,
        'reporterId': reporterId,
      },
    );

    debugPrint('📬 Уведомление о жалобе на фото $photoId');
  }

  void dispose() {
    _notificationController.close();
  }
}

/// Модель уведомления о "Интересно"
class InterestNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final String noteId;
  final String interestedUserId;
  final String interestedUserName;
  final DateTime timestamp;

  InterestNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    required this.noteId,
    required this.interestedUserId,
    required this.interestedUserName,
    required this.timestamp,
  });

  bool get isInterest => type == 'interest';
  bool get isContactApproved => type == 'contact_approved';
  bool get isPhotoComplaint => type == 'photo_complaint';
}
