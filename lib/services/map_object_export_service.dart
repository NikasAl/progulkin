import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/map_objects/map_objects.dart';
import '../services/p2p/map_object_storage.dart';
import '../di/service_locator.dart';

/// Результат экспорта
class ExportResult {
  final bool success;
  final String? filePath;
  final int objectsCount;
  final String? error;
  final int fileSizeBytes;

  ExportResult({
    required this.success,
    this.filePath,
    this.objectsCount = 0,
    this.error,
    this.fileSizeBytes = 0,
  });

  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes Б';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} КБ';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
}

/// Результат импорта
class ImportResult {
  final bool success;
  final int imported;
  final int skipped;
  final int errors;
  final List<String> errorDetails;
  final List<String> importedObjects;

  ImportResult({
    required this.success,
    this.imported = 0,
    this.skipped = 0,
    this.errors = 0,
    this.errorDetails = const [],
    this.importedObjects = const [],
  });

  String get summary {
    if (!success && imported == 0) {
      return 'Импорт не удался';
    }
    return 'Импортировано: $imported, пропущено: $skipped, ошибок: $errors';
  }
}

/// Сервис экспорта/импорта объектов карты в человекочитаемом формате
class MapObjectExportService {
  static final MapObjectExportService _instance = MapObjectExportService._internal();
  factory MapObjectExportService() => _instance;
  MapObjectExportService._internal();

  final MapObjectStorage _storage = getIt<MapObjectStorage>();

  /// Версия формата экспорта
  static const int formatVersion = 1;

  /// Экспортировать все объекты в файл
  Future<ExportResult> exportToFile({String? customPath}) async {
    try {
      // Получаем все объекты
      final objects = await _storage.getAllObjects();

      if (objects.isEmpty) {
        return ExportResult(
          success: false,
          error: 'Нет объектов для экспорта',
        );
      }

      // Создаём структуру экспорта
      final exportData = _createExportData(objects);

      // Форматируем JSON с отступами для читаемости
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Определяем путь к файлу
      final filePath = customPath ?? await _generateExportPath();

      // Записываем файл
      final file = File(filePath);
      await file.writeAsString(jsonString);

      final fileSize = await file.length();

      debugPrint('📤 Экспорт завершён: ${objects.length} объектов в $filePath');

      return ExportResult(
        success: true,
        filePath: filePath,
        objectsCount: objects.length,
        fileSizeBytes: fileSize,
      );
    } catch (e) {
      debugPrint('❌ Ошибка экспорта: $e');
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Экспортировать и поделиться файлом
  Future<ExportResult> exportAndShare() async {
    try {
      final result = await exportToFile();

      if (!result.success || result.filePath == null) {
        return result;
      }

      // Делимся файлом
      await Share.shareXFiles(
        [XFile(result.filePath!)],
        subject: 'Объекты карты Progulkin (${result.objectsCount} шт.)',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Ошибка при отправке: $e');
      return ExportResult(
        success: false,
        error: 'Ошибка при отправке: $e',
      );
    }
  }

  /// Импортировать объекты из файла
  Future<ImportResult> importFromFile({String? customPath}) async {
    try {
      String? filePath = customPath;

      // Если путь не указан, открываем диалог выбора файла
      if (filePath == null) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          dialogTitle: 'Выберите файл экспорта объектов',
        );

        if (result == null || result.files.isEmpty) {
          return ImportResult(
            success: false,
            errorDetails: ['Файл не выбран'],
          );
        }

        filePath = result.files.first.path;
      }

      if (filePath == null) {
        return ImportResult(
          success: false,
          errorDetails: ['Не удалось получить путь к файлу'],
        );
      }

      // Читаем файл
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(
          success: false,
          errorDetails: ['Файл не найден: $filePath'],
        );
      }

      final jsonString = await file.readAsString();

      // Парсим JSON
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Проверяем формат
      if (!_validateExportFormat(jsonData)) {
        return ImportResult(
          success: false,
          errorDetails: ['Неверный формат файла экспорта'],
        );
      }

      // Импортируем объекты
      return await _importObjects(jsonData);
    } catch (e) {
      debugPrint('❌ Ошибка импорта: $e');
      return ImportResult(
        success: false,
        errorDetails: ['Ошибка при чтении файла: $e'],
      );
    }
  }

  /// Создать структуру данных для экспорта
  Map<String, dynamic> _createExportData(List<MapObject> objects) {
    // Группируем объекты по типам
    final trashMonsters = <Map<String, dynamic>>[];
    final secretMessages = <Map<String, dynamic>>[];
    final creatures = <Map<String, dynamic>>[];

    for (final obj in objects) {
      final json = obj.toSyncJson();

      // Добавляем человекочитаемое описание
      json['_description'] = obj.shortDescription;
      json['_geohash'] = obj.geohash;

      switch (obj.type) {
        case MapObjectType.trashMonster:
          trashMonsters.add(json);
        case MapObjectType.secretMessage:
          // Для секретных сообщений не экспортируем зашифрованный контент как есть
          // Расшифровываем для читаемости
          json['decryptedContent'] = (obj as SecretMessage).originalContent;
          secretMessages.add(json);
        case MapObjectType.creature:
          creatures.add(json);
        default:
          break;
      }
    }

    return {
      '_meta': {
        'formatVersion': formatVersion,
        'appName': 'Progulkin',
        'exportDate': DateTime.now().toIso8601String(),
        'totalObjects': objects.length,
        'description': 'Экспорт объектов карты прогулок',
        'legend': {
          'trash_monster': 'Мусорный монстр - место где замечен мусор',
          'secret_message': 'Секретное сообщение - можно прочитать только на месте',
          'creature': 'Существо - можно поймать и приручить',
        },
        'statuses': {
          'active': 'Активный',
          'confirmed': 'Подтверждённый',
          'cleaned': 'Убранный',
          'expired': 'Истёкший',
          'hidden': 'Скрытый',
        },
      },
      'trashMonsters': trashMonsters,
      'secretMessages': secretMessages,
      'creatures': creatures,
    };
  }

  /// Проверить формат файла экспорта
  bool _validateExportFormat(Map<String, dynamic> data) {
    // Проверяем наличие мета-данных
    if (!data.containsKey('_meta')) return false;

    final meta = data['_meta'] as Map<String, dynamic>?;

    // Проверяем версию формата
    final version = meta?['formatVersion'] as int?;
    if (version == null || version > formatVersion) return false;

    // Проверяем наличие хотя бы одного списка объектов
    return data.containsKey('trashMonsters') ||
        data.containsKey('secretMessages') ||
        data.containsKey('creatures');
  }

  /// Импортировать объекты из структуры данных
  Future<ImportResult> _importObjects(Map<String, dynamic> data) async {
    int imported = 0;
    int skipped = 0;
    int errors = 0;
    final errorDetails = <String>[];
    final importedObjects = <String>[];

    // Импортируем мусорных монстров
    if (data.containsKey('trashMonsters')) {
      final result = await _importObjectList(
        data['trashMonsters'] as List,
        'trash_monster',
      );
      imported += result.imported;
      skipped += result.skipped;
      errors += result.errors;
      errorDetails.addAll(result.errorDetails);
      importedObjects.addAll(result.importedObjects);
    }

    // Импортируем секретные сообщения
    if (data.containsKey('secretMessages')) {
      final result = await _importObjectList(
        data['secretMessages'] as List,
        'secret_message',
      );
      imported += result.imported;
      skipped += result.skipped;
      errors += result.errors;
      errorDetails.addAll(result.errorDetails);
      importedObjects.addAll(result.importedObjects);
    }

    // Импортируем существ
    if (data.containsKey('creatures')) {
      final result = await _importObjectList(
        data['creatures'] as List,
        'creature',
      );
      imported += result.imported;
      skipped += result.skipped;
      errors += result.errors;
      errorDetails.addAll(result.errorDetails);
      importedObjects.addAll(result.importedObjects);
    }

    debugPrint('📥 Импорт завершён: импортировано=$imported, пропущено=$skipped, ошибок=$errors');

    return ImportResult(
      success: imported > 0,
      imported: imported,
      skipped: skipped,
      errors: errors,
      errorDetails: errorDetails,
      importedObjects: importedObjects,
    );
  }

  /// Импортировать список объектов одного типа
  Future<ImportResult> _importObjectList(List list, String type) async {
    int imported = 0;
    int skipped = 0;
    int errors = 0;
    final errorDetails = <String>[];
    final importedObjects = <String>[];

    for (final item in list) {
      try {
        final json = item as Map<String, dynamic>;

        // Проверяем, существует ли уже объект
        final existingObject = await _storage.getObject(json['id'] as String);

        if (existingObject != null) {
          // Если существующий объект новее - пропускаем
          if (existingObject.version >= (json['version'] as int? ?? 1)) {
            skipped++;
            continue;
          }
        }

        // Удаляем служебные поля
        final cleanJson = Map<String, dynamic>.from(json);
        cleanJson.remove('_description');
        cleanJson.remove('_geohash');
        cleanJson.remove('decryptedContent');

        // Создаём объект
        final object = MapObject.fromSyncJson(cleanJson);

        // Сохраняем
        await _storage.saveObject(object);

        imported++;
        importedObjects.add('${object.type.emoji} ${object.shortDescription}');
      } catch (e) {
        errors++;
        errorDetails.add('Ошибка импорта $type: $e');
        debugPrint('⚠️ Ошибка импорта объекта: $e');
      }
    }

    return ImportResult(
      success: imported > 0,
      imported: imported,
      skipped: skipped,
      errors: errors,
      errorDetails: errorDetails,
      importedObjects: importedObjects,
    );
  }

  /// Сгенерировать путь для экспорта
  Future<String> _generateExportPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    return '${directory.path}/map_objects_export_$timestamp.json';
  }

  /// Получить статистику экспорта (без создания файла)
  Future<Map<String, dynamic>> getExportStats() async {
    final objects = await _storage.getAllObjects();

    final stats = <String, int>{
      'total': objects.length,
      'trashMonsters': objects.where((o) => o.type == MapObjectType.trashMonster).length,
      'secretMessages': objects.where((o) => o.type == MapObjectType.secretMessage).length,
      'creatures': objects.where((o) => o.type == MapObjectType.creature).length,
    };

    return stats;
  }
}
