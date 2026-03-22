/// Пример файла конфигурации.
/// 
/// Скопируйте этот файл как `app_config.dart` и заполните своими значениями:
/// ```
/// cp lib/config/app_config.example.dart lib/config/app_config.dart
/// ```
/// 
/// Файл app_config.dart добавлен в .gitignore и не будет комититься в репозиторий.
class AppConfig {
  /// API ключ для Яндекс карт
  /// Получить можно здесь: https://developer.tech.yandex.ru/
  static const String yandexMapApiKey = 'YOUR_YANDEX_MAP_API_KEY';
  
  /// Название приложения
  static const String appName = 'Прогулкин';
  
  /// Версия приложения
  static const String appVersion = '1.0.0';
  
  /// Минимальное расстояние между точками трекинга (в метрах)
  static const int trackingDistanceFilter = 5;
  
  /// Интервал обновления позиции (в секундах)
  static const int trackingIntervalSeconds = 1;
  
  /// Средняя длина шага (в метрах) для расчёта расстояния
  static const double averageStepLength = 0.76;
  
  /// Минимальный интервал между шагами (в миллисекундах)
  static const int minStepIntervalMs = 200;
  
  /// Порог для детекции шага через акселерометр
  static const double stepDetectionThreshold = 12.0;
  
  /// Включить логирование (только для debug)
  static const bool enableLogging = true;
}
