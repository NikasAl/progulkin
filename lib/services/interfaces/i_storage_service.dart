import '../../models/walk.dart';

/// Интерфейс сервиса хранения данных для тестирования и расширяемости
///
/// Позволяет создавать моки для unit-тестов и альтернативные
/// реализации (например, облачное хранилище).
abstract class IStorageService {
  /// Инициализация хранилища
  Future<void> init();

  /// Сохранить прогулку
  Future<void> saveWalk(Walk walk);

  /// Получить все прогулки
  Future<List<Walk>> getAllWalks();

  /// Получить прогулку по ID
  Future<Walk?> getWalk(String id);

  /// Удалить прогулку
  Future<void> deleteWalk(String id);

  /// Получить статистику
  Future<Map<String, dynamic>> getStatistics();

  /// Очистить все данные
  Future<void> clearAll();
}
