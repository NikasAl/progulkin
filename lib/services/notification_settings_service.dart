import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Настройки уведомлений
class NotificationSettings extends ChangeNotifier {
  bool soundEnabled;
  bool vibrationEnabled;
  bool enabled;

  NotificationSettings({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.enabled = true,
  });

  NotificationSettings copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? enabled,
  }) {
    return NotificationSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Сервис управления настройками уведомлений
class NotificationSettingsService extends ChangeNotifier {
  static const String _keyEnabled = 'notification_enabled';
  static const String _keySoundEnabled = 'notification_sound_enabled';
  static const String _keyVibrationEnabled = 'notification_vibration_enabled';

  NotificationSettings _settings = NotificationSettings();
  bool _initialized = false;

  NotificationSettings get settings => _settings;
  bool get soundEnabled => _settings.soundEnabled;
  bool get vibrationEnabled => _settings.vibrationEnabled;
  bool get enabled => _settings.enabled;

  /// Инициализация - загрузка настроек из SharedPreferences
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    
    _settings = NotificationSettings(
      enabled: prefs.getBool(_keyEnabled) ?? true,
      soundEnabled: prefs.getBool(_keySoundEnabled) ?? true,
      vibrationEnabled: prefs.getBool(_keyVibrationEnabled) ?? true,
    );
    
    notifyListeners();
  }

  /// Включить/выключить уведомления
  Future<void> setEnabled(bool value) async {
    _settings = _settings.copyWith(enabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    notifyListeners();
  }

  /// Включить/выключить звук уведомлений
  Future<void> setSoundEnabled(bool value) async {
    _settings = _settings.copyWith(soundEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySoundEnabled, value);
    notifyListeners();
  }

  /// Включить/выключить вибрацию при уведомлении
  Future<void> setVibrationEnabled(bool value) async {
    _settings = _settings.copyWith(vibrationEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibrationEnabled, value);
    notifyListeners();
  }

  /// Обновить все настройки сразу
  Future<void> updateSettings({
    bool? enabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) async {
    _settings = _settings.copyWith(
      enabled: enabled,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
    
    final prefs = await SharedPreferences.getInstance();
    if (enabled != null) await prefs.setBool(_keyEnabled, enabled);
    if (soundEnabled != null) await prefs.setBool(_keySoundEnabled, soundEnabled);
    if (vibrationEnabled != null) await prefs.setBool(_keyVibrationEnabled, vibrationEnabled);
    
    notifyListeners();
  }
}
