import '../sync_service.dart';
import '../merge_engine.dart';

/// Интерфейс сервиса синхронизации для тестирования и расширяемости
///
/// Позволяет создавать моки для unit-тестов и альтернативные
/// реализации (например, облачную синхронизацию).
abstract class ISyncService {
  /// Экспортировать все объекты в ZIP-архив
  Future<ZipExportResult> exportToZip();

  /// Экспортировать и поделиться
  Future<ZipExportResult> exportAndShare();

  /// Импортировать из ZIP-архива
  Future<ZipImportResult> importFromZip({
    MergeStrategy strategy,
    bool requireUserConfirmation,
  });

  /// Импортировать из конкретного пути
  Future<ZipImportResult> importFromPath(
    String filePath, {
    MergeStrategy strategy,
  });

  /// Разрешить конфликт и применить выбранное решение
  Future<void> resolveConflict(
    MergeConflict conflict,
    MergeStrategy strategy,
  );

  /// Получить превью файла импорта (без применения)
  Future<Map<String, dynamic>?> getImportPreview(String filePath);

  /// Получить статистику для экспорта
  Future<Map<String, dynamic>> getExportStats();
}
