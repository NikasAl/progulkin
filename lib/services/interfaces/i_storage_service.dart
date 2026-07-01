import '../../models/walk.dart';
import '../storage_service.dart';

/// Интерфейс сервиса хранения данных для тестирования и расширяемости
///
/// Позволяет создавать моки для unit-тестов и альтернативные
/// реализации (например, облачное хранилище).
abstract class IStorageService {
  /// Инициализация хранилища
  Future<void> init();

  /// Сохранить прогулку
  Future<bool> saveWalk(Walk walk);

  /// Получить метаданные прогулок (без точек) - быстро
  Future<List<WalkMetadata>> getAllWalksMetadata();

  /// Получить метаданные с пагинацией
  Future<List<WalkMetadata>> getWalksMetadataPaginated({
    int limit,
    int offset,
  });

  /// Количество прогулок
  Future<int> getWalksCount();

  /// Получить полный Walk (с точками) по ID
  Future<Walk?> getWalkById(String id);

  /// Удалить прогулку
  Future<bool> deleteWalk(String id);

  /// Удалить все прогулки
  Future<bool> deleteAllWalks();

  /// Получить статистику
  Future<Map<String, dynamic>> getStatistics();

  /// Очистить все данные
  Future<bool> clearAll();
}
