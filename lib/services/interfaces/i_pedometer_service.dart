/// Интерфейс сервиса шагомера для тестирования и расширяемости
///
/// Позволяет создавать моки для unit-тестов и альтернативные
/// реализации (например, для симуляции шагов в тестах).
abstract class IPedometerService {
  /// Поток шагов
  Stream<int> get stepsStream;

  /// Поток расстояния
  Stream<double> get distanceStream;

  /// Текущее количество шагов
  int get currentSteps;

  /// Текущее расстояние в метрах
  double get currentDistance;

  /// Проверка разрешений
  Future<bool> checkPermission();

  /// Начать подсчёт шагов
  Future<void> startCounting();

  /// Приостановить подсчёт (без сброса)
  void pauseCounting();

  /// Продолжить подсчёт после паузы
  Future<void> resumeCounting();

  /// Остановить подсчёт и сбросить счётчик
  void stopCounting();

  /// Сбросить счётчик
  void reset();

  /// Установить среднюю длину шага
  void setAverageStepLength(double meters);

  /// Освобождение ресурсов
  void dispose();
}
