/// Конфигурация приложения
class AppConfig {
  // Название приложения
  static const String appName = 'Прогулкин';

  // Настройки логирования
  static const bool enableLogging = true;

  // Настройки трекинга
  static const int trackingDistanceFilter = 0; // метров между точками (0 = все точки)
  
  // Настройки шагомера
  static const double averageStepLength = 0.75; // средняя длина шага в метрах
  static const double stepDetectionThreshold = 25.0; // порог для детекции шага через акселерометр
  static const int minStepIntervalMs = 250; // минимальный интервал между шагами в мс
}
