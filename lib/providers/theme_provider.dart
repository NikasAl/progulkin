import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Провайдер для управления темой приложения
class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  ThemeProvider() {
    _loadThemeMode();
  }
  
  /// Загрузить сохранённую тему
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeModeKey);
    
    if (savedMode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }
  
  /// Установить тему
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
    
    notifyListeners();
  }
  
  /// Переключить тему по циклу: system -> light -> dark -> system
  Future<void> cycleThemeMode() async {
    ThemeMode nextMode;
    switch (_themeMode) {
      case ThemeMode.system:
        nextMode = ThemeMode.light;
      case ThemeMode.light:
        nextMode = ThemeMode.dark;
      case ThemeMode.dark:
        nextMode = ThemeMode.system;
    }
    await setThemeMode(nextMode);
  }
  
  /// Название текущей темы для отображения
  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.system:
        return 'Авто';
      case ThemeMode.light:
        return 'Светлая';
      case ThemeMode.dark:
        return 'Тёмная';
    }
  }
  
  /// Иконка текущей темы
  IconData get themeModeIcon {
    switch (_themeMode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }
}
