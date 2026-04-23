import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/map_objects/map_objects.dart';
import '../providers/map_object_provider.dart';
import 'notification_settings_service.dart';

/// Результат срабатывания напоминания
class ReminderTrigger {
  final ReminderCharacter reminder;
  final DateTime triggeredAt;
  final double distance;

  const ReminderTrigger({
    required this.reminder,
    required this.triggeredAt,
    required this.distance,
  });
}

/// Сервис гео-напоминаний
/// Отслеживает позицию пользователя и генерирует уведомления при приближении к напоминаниям
class ReminderService extends ChangeNotifier {
  final MapObjectProvider _mapObjectProvider;
  final NotificationSettingsService _notificationSettings;
  final FlutterLocalNotificationsPlugin _notifications;

  // Пользовательские напоминания (только свои)
  List<ReminderCharacter> _myReminders = [];

  // Недавно сработавшие напоминания (для избежания повторов)
  final Map<String, DateTime> _recentlyTriggered = {};

  // Текущая позиция
  double? _currentLat;
  double? _currentLng;

  // Поток срабатываний
  final StreamController<ReminderTrigger> _triggerController =
      StreamController<ReminderTrigger>.broadcast();

  Stream<ReminderTrigger> get triggerStream => _triggerController.stream;

  // Настройки
  bool _notificationsEnabled = true;
  Duration _snoozeDuration = const Duration(minutes: 30);
  final Duration _repeatCooldown = const Duration(minutes: 5);

  bool get notificationsEnabled => _notificationsEnabled;
  Duration get snoozeDuration => _snoozeDuration;

  List<ReminderCharacter> get myReminders => List.unmodifiable(_myReminders);
  List<ReminderCharacter> get activeReminders =>
      _myReminders.where((r) => r.isActive).toList();
  List<ReminderCharacter> get snoozedReminders =>
      _myReminders.where((r) => r.snoozedUntil != null && DateTime.now().isBefore(r.snoozedUntil!)).toList();

  ReminderService(this._mapObjectProvider, this._notificationSettings)
      : _notifications = FlutterLocalNotificationsPlugin() {
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      defaultPresentSound: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Создаём канал уведомлений с настройками звука и вибрации
    await _createNotificationChannel();
  }

  /// Создать канал уведомлений Android с настройками
  Future<void> _createNotificationChannel() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'reminders',
          'Напоминания',
          description: 'Гео-напоминания от Смешариков',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // TODO: Открыть детали напоминания
    debugPrint('🔔 Нажато уведомление: ${response.payload}');
  }

  /// Загрузить напоминания пользователя
  Future<void> loadMyReminders(String userId) async {
    final allObjects = _mapObjectProvider.allObjects;
    _myReminders = allObjects
        .whereType<ReminderCharacter>()
        .where((r) => r.ownerId == userId)
        .toList();
    notifyListeners();
  }

  /// Обновить позицию пользователя и проверить напоминания
  Future<void> updatePosition(double lat, double lng, String userId) async {
    _currentLat = lat;
    _currentLng = lng;

    // Очищаем старые записи о срабатываниях
    _cleanOldTriggers();

    // Проверяем все активные напоминания пользователя
    for (final reminder in _myReminders) {
      if (reminder.shouldTrigger(lat, lng)) {
        await _checkAndTrigger(reminder, lat, lng);
      }
    }
  }

  /// Проверить и сработать напоминание
  Future<void> _checkAndTrigger(ReminderCharacter reminder, double lat, double lng) async {
    final now = DateTime.now();
    final lastTriggered = _recentlyTriggered[reminder.id];

    // Проверяем кулдаун
    if (lastTriggered != null &&
        now.difference(lastTriggered) < _repeatCooldown) {
      return;
    }

    // Вычисляем расстояние
    final distance = calculateDistance(
      lat, lng,
      reminder.latitude, reminder.longitude,
    );

    // Записываем срабатывание
    _recentlyTriggered[reminder.id] = now;

    // Генерируем уведомление
    if (_notificationsEnabled) {
      await _showNotification(reminder, distance);
    }

    // Отправляем в поток
    _triggerController.add(ReminderTrigger(
      reminder: reminder,
      triggeredAt: now,
      distance: distance,
    ));

    debugPrint('🔔 Напоминание сработало: ${reminder.characterType.emoji} ${reminder.reminderText}');

    // Увеличиваем счётчик срабатываний
    final updated = reminder.markTriggered();
    await _mapObjectProvider.storage.updateObject(updated);

    // Обновляем локальный список
    final index = _myReminders.indexWhere((r) => r.id == reminder.id);
    if (index >= 0) {
      _myReminders[index] = updated;
    }

    notifyListeners();
  }

  /// Показать уведомление
  Future<void> _showNotification(ReminderCharacter reminder, double distance) async {
    final soundEnabled = _notificationSettings.soundEnabled;
    final vibrationEnabled = _notificationSettings.vibrationEnabled;
    
    final androidDetails = AndroidNotificationDetails(
      'reminders',
      'Напоминания',
      channelDescription: 'Гео-напоминания от Смешариков',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/splash_icon',
      playSound: soundEnabled,
      enableVibration: vibrationEnabled,
      vibrationPattern: vibrationEnabled ? Int64List.fromList([0, 500, 200, 500]) : null,
      // Используем системный звук уведомления (null = звук канала по умолчанию)
      sound: null,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundEnabled,
      sound: soundEnabled ? 'default' : null,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      reminder.id.hashCode,
      '${reminder.characterType.emoji} ${reminder.characterType.name}',
      reminder.reminderText,
      details,
      payload: reminder.id,
    );
  }

  /// Очистить старые записи о срабатываниях
  void _cleanOldTriggers() {
    final now = DateTime.now();
    _recentlyTriggered.removeWhere(
      (key, time) => now.difference(time) > const Duration(hours: 1),
    );
  }

  /// Отложить напоминание
  Future<void> snoozeReminder(String reminderId, {Duration? duration}) async {
    final reminder = _myReminders.firstWhere((r) => r.id == reminderId);
    final snoozed = reminder.snooze(duration ?? _snoozeDuration);

    await _mapObjectProvider.storage.updateObject(snoozed);

    final index = _myReminders.indexWhere((r) => r.id == reminderId);
    if (index >= 0) {
      _myReminders[index] = snoozed;
    }

    notifyListeners();
  }

  /// Деактивировать напоминание
  Future<void> deactivateReminder(String reminderId) async {
    final reminder = _myReminders.firstWhere((r) => r.id == reminderId);
    final deactivated = reminder.deactivate();

    await _mapObjectProvider.storage.updateObject(deactivated);

    final index = _myReminders.indexWhere((r) => r.id == reminderId);
    if (index >= 0) {
      _myReminders[index] = deactivated;
    }

    notifyListeners();
  }

  /// Активировать напоминание
  Future<void> activateReminder(String reminderId) async {
    final reminder = _myReminders.firstWhere((r) => r.id == reminderId);
    final activated = reminder.activate();

    await _mapObjectProvider.storage.updateObject(activated);

    final index = _myReminders.indexWhere((r) => r.id == reminderId);
    if (index >= 0) {
      _myReminders[index] = activated;
    }

    notifyListeners();
  }

  /// Удалить напоминание
  Future<void> deleteReminder(String reminderId, String userId) async {
    await _mapObjectProvider.deleteObject(reminderId, userId);
    _myReminders.removeWhere((r) => r.id == reminderId);
    notifyListeners();
  }

  /// Обновить текст напоминания
  Future<void> updateReminderText(String reminderId, String newText) async {
    final reminder = _myReminders.firstWhere((r) => r.id == reminderId);
    final updated = reminder.updateText(newText);

    await _mapObjectProvider.storage.updateObject(updated);

    final index = _myReminders.indexWhere((r) => r.id == reminderId);
    if (index >= 0) {
      _myReminders[index] = updated;
    }

    notifyListeners();
  }

  /// Обновить радиус срабатывания
  Future<void> updateReminderRadius(String reminderId, double newRadius) async {
    final reminder = _myReminders.firstWhere((r) => r.id == reminderId);
    final updated = reminder.updateRadius(newRadius);

    await _mapObjectProvider.storage.updateObject(updated);

    final index = _myReminders.indexWhere((r) => r.id == reminderId);
    if (index >= 0) {
      _myReminders[index] = updated;
    }

    notifyListeners();
  }

  /// Включить/выключить уведомления
  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }

  /// Установить длительность откладывания
  void setSnoozeDuration(Duration duration) {
    _snoozeDuration = duration;
    notifyListeners();
  }

  /// Получить расстояние до напоминания
  double? getDistanceToReminder(ReminderCharacter reminder) {
    if (_currentLat == null || _currentLng == null) return null;

    return calculateDistance(
      _currentLat!, _currentLng!,
      reminder.latitude, reminder.longitude,
    );
  }

  /// Форматировать расстояние
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} м';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} км';
    }
  }

  /// Получить список напоминаний, которые скоро сработают
  List<ReminderCharacter> getUpcomingReminders({double maxDistance = 1000}) {
    if (_currentLat == null || _currentLng == null) return [];

    return _myReminders.where((r) {
      if (!r.isActive) return false;
      if (r.snoozedUntil != null && DateTime.now().isBefore(r.snoozedUntil!)) {
        return false;
      }

      final distance = getDistanceToReminder(r);
      return distance != null && distance <= maxDistance;
    }).toList()
      ..sort((a, b) {
        final distA = getDistanceToReminder(a) ?? double.infinity;
        final distB = getDistanceToReminder(b) ?? double.infinity;
        return distA.compareTo(distB);
      });
  }

  @override
  void dispose() {
    _triggerController.close();
    super.dispose();
  }
}
