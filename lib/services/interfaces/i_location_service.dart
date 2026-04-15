import '../walk_point.dart';

/// Интерфейс сервиса геолокации для тестирования и расширяемости
///
/// Позволяет создавать моки для unit-тестов и альтернативные
/// реализации (например, для симуляции маршрутов).
abstract class ILocationService {
  /// Поток позиций для подписки
  Stream<WalkPoint> get positionStream;

  /// Проверка разрешений на геолокацию
  Future<bool> checkPermission();

  /// Получить текущую позицию
  Future<WalkPoint?> getCurrentPosition();

  /// Начать отслеживание позиции
  Future<void> startTracking();

  /// Остановить отслеживание
  void stopTracking();

  /// Проверка, активно ли отслеживание
  bool get isTracking;

  /// Проверка, неподвижен ли пользователь
  bool get isStationary;

  /// Статистика фильтрации
  Map<String, dynamic> get filterStats;

  /// Обновить настройки фильтрации
  void updateSettings({
    double? maxSpeed,
    double? maxAccuracy,
    bool? smoothing,
    double? stationaryRadius,
    bool? stationaryDetection,
    bool? adaptiveSmoothing,
    double? turnThreshold,
    double? smoothingWeight,
  });

  /// Освобождение ресурсов
  void dispose();
}
