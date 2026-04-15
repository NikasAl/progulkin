import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import '../models/map_objects/map_objects.dart';
import 'p2p/map_object_storage.dart';
import 'merge_engine.dart';
import '../di/service_locator.dart';

/// Результат экспорта в ZIP
class ZipExportResult {
  final bool success;
  final String? filePath;
  final int objectsCount;
  final int photosCount;
  final int fileSizeBytes;
  final String? error;

  ZipExportResult({
    required this.success,
    this.filePath,
    this.objectsCount = 0,
    this.photosCount = 0,
    this.fileSizeBytes = 0,
    this.error,
  });

  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes Б';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} КБ';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
}

/// Результат импорта из ZIP
class ZipImportResult {
  final bool success;
  final MergeResult? mergeResult;
  final int photosImported;
  final String? error;
  final List<MergeConflict>? conflicts;

  ZipImportResult({
    required this.success,
    this.mergeResult,
    this.photosImported = 0,
    this.error,
    this.conflicts,
  });

  String get summary {
    if (!success) return error ?? 'Ошибка импорта';
    final merge = mergeResult?.summary ?? 'нет изменений';
    final photos = photosImported > 0 ? ', фото: $photosImported' : '';
    return '$merge$photos';
  }

  bool get hasConflicts => conflicts != null && conflicts!.isNotEmpty;
}

/// Сервис синхронизации объектов карты через ZIP-архивы
class SyncService {
  final MapObjectStorage _storage = getIt<MapObjectStorage>();
  final MergeEngine _mergeEngine = MergeEngine();

  /// Версия формата экспорта
  static const int formatVersion = 2;

  /// Расширение файла экспорта
  static const String fileExtension = 'progulkin';

  /// Экспортировать все объекты в ZIP-архив
  Future<ZipExportResult> exportToZip() async {
    try {
      // Получаем все объекты (включая удалённые для корректного мержа)
      final objects = await _storage.getAllObjectsForSync();

      if (objects.isEmpty) {
        return ZipExportResult(
          success: false,
          error: 'Нет объектов для экспорта',
        );
      }

      // Собираем все ID фото
      final allPhotoIds = <String>{};
      for (final obj in objects) {
        if (obj is TrashMonster) {
          allPhotoIds.addAll(obj.photoIds);
        } else if (obj is InterestNote) {
          allPhotoIds.addAll(obj.photoIds);
        }
      }

      // Загружаем фото
      final photos = <String, Uint8List>{};
      for (final photoId in allPhotoIds) {
        final photoData = await _storage.getPhoto(photoId);
        if (photoData != null && photoData['webp_data'] != null) {
          photos[photoId] = photoData['webp_data'] as Uint8List;
        }
      }

      // Создаём манифест
      final manifest = {
        'formatVersion': formatVersion,
        'appName': 'Progulkin',
        'exportDate': DateTime.now().toIso8601String(),
        'deviceId': await _getDeviceId(),
        'totalObjects': objects.length,
        'totalPhotos': photos.length,
        'description': 'Экспорт карты Прогулкин',
      };

      // Сериализуем объекты
      final objectsJson = objects.map((obj) => obj.toSyncJson()).toList();

      // Создаём архив
      final archive = Archive();

      // Добавляем манифест
      archive.addFile(ArchiveFile.string(
        'manifest.json',
        const JsonEncoder.withIndent('  ').convert(manifest),
      ));

      // Добавляем объекты
      archive.addFile(ArchiveFile.string(
        'objects.json',
        const JsonEncoder.withIndent('  ').convert(objectsJson),
      ));

      // Добавляем фото в папку photos/
      for (final entry in photos.entries) {
        archive.addFile(ArchiveFile(
          'photos/${entry.key}.webp',
          entry.value.length,
          entry.value,
        ));
      }

      // Добавляем превью для быстрого просмотра
      final preview = _createPreview(objects);
      archive.addFile(ArchiveFile.string(
        'preview.json',
        const JsonEncoder.withIndent('  ').convert(preview),
      ));

      // Кодируем в ZIP
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        return ZipExportResult(
          success: false,
          error: 'Ошибка создания архива',
        );
      }

      // Сохраняем файл
      final filePath = await _generateExportPath();
      final file = File(filePath);
      await file.writeAsBytes(zipBytes);

      final fileSize = await file.length();

      debugPrint('📦 Экспорт завершён: ${objects.length} объектов, ${photos.length} фото в $filePath');

      return ZipExportResult(
        success: true,
        filePath: filePath,
        objectsCount: objects.length,
        photosCount: photos.length,
        fileSizeBytes: fileSize,
      );
    } catch (e) {
      debugPrint('❌ Ошибка экспорта: $e');
      return ZipExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Экспортировать и поделиться
  Future<ZipExportResult> exportAndShare() async {
    try {
      final result = await exportToZip();

      if (!result.success || result.filePath == null) {
        return result;
      }

      await Share.shareXFiles(
        [XFile(result.filePath!)],
        subject: 'Карта Прогулкин (${result.objectsCount} объектов)',
        text: 'Экспорт карты Прогулкин: ${result.objectsCount} объектов, ${result.photosCount} фото',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Ошибка при отправке: $e');
      return ZipExportResult(
        success: false,
        error: 'Ошибка при отправке: $e',
      );
    }
  }

  /// Импортировать из ZIP-архива
  Future<ZipImportResult> importFromZip({
    MergeStrategy strategy = MergeStrategy.newerWins,
    bool requireUserConfirmation = false,
  }) async {
    try {
      // Выбираем файл
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [fileExtension, 'zip'],
        dialogTitle: 'Выберите файл экспорта Прогулкин',
      );

      if (result == null || result.files.isEmpty) {
        return ZipImportResult(
          success: false,
          error: 'Файл не выбран',
        );
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        return ZipImportResult(
          success: false,
          error: 'Не удалось получить путь к файлу',
        );
      }

      return await importFromPath(filePath, strategy: strategy);
    } catch (e) {
      debugPrint('❌ Ошибка импорта: $e');
      return ZipImportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Импортировать из конкретного пути
  Future<ZipImportResult> importFromPath(
    String filePath, {
    MergeStrategy strategy = MergeStrategy.newerWins,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ZipImportResult(
          success: false,
          error: 'Файл не найден: $filePath',
        );
      }

      // Читаем и распаковываем ZIP
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Находим манифест
      ArchiveFile? manifestFile;
      ArchiveFile? objectsFile;
      final photoFiles = <ArchiveFile>[];

      for (final file in archive) {
        if (file.name == 'manifest.json') {
          manifestFile = file;
        } else if (file.name == 'objects.json') {
          objectsFile = file;
        } else if (file.name.startsWith('photos/')) {
          photoFiles.add(file);
        }
      }

      if (manifestFile == null || objectsFile == null) {
        return ZipImportResult(
          success: false,
          error: 'Неверный формат файла',
        );
      }

      // Проверяем версию
      final manifestJson = jsonDecode(utf8.decode(manifestFile.content))
          as Map<String, dynamic>;
      final version = manifestJson['formatVersion'] as int? ?? 1;

      if (version > formatVersion) {
        return ZipImportResult(
          success: false,
          error: 'Файл создан в более новой версии приложения',
        );
      }

      // Парсим объекты
      final objectsJson = jsonDecode(utf8.decode(objectsFile.content)) as List;
      final remoteObjects = objectsJson.map((json) {
        return MapObject.fromSyncJson(json as Map<String, dynamic>);
      }).toList();

      // Получаем локальные объекты
      final localObjects = await _storage.getAllObjectsForSync();

      // Выполняем мерж
      final mergeResult = await _mergeEngine.merge(
        localObjects: localObjects,
        remoteObjects: remoteObjects,
        strategy: strategy,
      );

      // Применяем результат мержа
      int photosImported = 0;

      // Сохраняем импортированные/обновлённые объекты
      for (final obj in remoteObjects) {
        // Пропускаем конфликтующие (они требуют решения пользователя)
        if (mergeResult.conflictList.any((c) => c.objectId == obj.id)) {
          continue;
        }

        // Проверяем, нужно ли обновлять
        final local = await _storage.getObject(obj.id);
        if (local != null) {
          if (obj.updatedAt.isAfter(local.updatedAt) || obj.version > local.version) {
            await _storage.saveObject(obj);
          }
        } else if (!obj.isDeleted) {
          await _storage.saveObject(obj);
        }
      }

      // Импортируем фото
      for (final photoFile in photoFiles) {
        final photoName = photoFile.name.split('/').last;
        final photoId = photoName.replaceAll('.webp', '');

        // Сохраняем фото в хранилище
        await _storage.savePhoto(
          id: photoId,
          webpData: Uint8List.fromList(photoFile.content),
          status: 'imported',
        );
        photosImported++;
      }

      debugPrint('📥 Импорт завершён: ${mergeResult.summary}, фото: $photosImported');

      return ZipImportResult(
        success: true,
        mergeResult: mergeResult,
        photosImported: photosImported,
        conflicts: mergeResult.conflictList.isNotEmpty ? mergeResult.conflictList : null,
      );
    } catch (e) {
      debugPrint('❌ Ошибка импорта: $e');
      return ZipImportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Разрешить конфликт и применить выбранное решение
  Future<void> resolveConflict(
    MergeConflict conflict,
    MergeStrategy strategy,
  ) async {
    final resolved = _mergeEngine.resolveConflict(conflict, strategy);
    await _storage.saveObject(resolved);
  }

  /// Получить превью файла импорта (без применения)
  Future<Map<String, dynamic>?> getImportPreview(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (file.name == 'preview.json') {
          final previewJson = utf8.decode(file.content);
          return jsonDecode(previewJson) as Map<String, dynamic>;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Ошибка чтения превью: $e');
      return null;
    }
  }

  /// Создать превью для архива
  Map<String, dynamic> _createPreview(List<MapObject> objects) {
    final stats = <String, int>{};
    final samples = <Map<String, dynamic>>[];

    for (final obj in objects) {
      final type = obj.type.code;
      stats[type] = (stats[type] ?? 0) + 1;

      if (samples.length < 10) {
        samples.add({
          'type': obj.type.code,
          'description': obj.shortDescription,
          'lat': obj.latitude,
          'lng': obj.longitude,
          'deleted': obj.isDeleted,
        });
      }
    }

    return {
      'stats': stats,
      'samples': samples,
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  /// Сгенерировать путь для экспорта (в папку Downloads)
  Future<String> _generateExportPath() async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final fileName = 'progulkin_export_$timestamp.$fileExtension';
    
    // Пытаемся сохранить в Downloads на Android
    if (Platform.isAndroid) {
      try {
        // На Android 10+ используем MediaStore через MethodChannel
        // На более старых - прямой путь к Downloads
        final directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) {
          final filePath = '${directory.path}/$fileName';
          // Проверяем, можем ли записать
          try {
            final testFile = File('${directory.path}/.test_write');
            await testFile.writeAsString('test');
            await testFile.delete();
            return filePath;
          } catch (e) {
            debugPrint('⚠️ Нет доступа к Downloads: $e');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Ошибка доступа к Downloads: $e');
      }
    }
    
    // Fallback - папка приложения
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$fileName';
  }

  /// Получить ID устройства
  Future<String> _getDeviceId() async {
    // В реальном приложении лучше использовать device_info_plus
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Получить статистику для экспорта
  Future<Map<String, dynamic>> getExportStats() async {
    final objects = await _storage.getAllObjectsForSync();

    final stats = <String, int>{
      'total': objects.length,
      'active': objects.where((o) => !o.isDeleted).length,
      'deleted': objects.where((o) => o.isDeleted).length,
    };

    for (final type in MapObjectType.values) {
      stats[type.code] = objects.where((o) => o.type == type).length;
    }

    return stats;
  }
}
