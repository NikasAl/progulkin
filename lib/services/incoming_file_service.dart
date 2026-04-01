import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'sync_service.dart';

/// Сервис для обработки входящих файлов (открытие через "Открыть с помощью")
class IncomingFileService {
  static final IncomingFileService _instance = IncomingFileService._internal();
  factory IncomingFileService() => _instance;
  IncomingFileService._internal();

  static const MethodChannel _channel = MethodChannel('ru.kreagenium.progulkin/incoming_file');
  
  final SyncService _syncService = SyncService();
  
  /// Callback при получении файла для импорта
  void Function(ZipImportResult result)? onFileReceived;
  
  /// Инициализировать слушатель входящих файлов
  void init() {
    _channel.setMethodCallHandler(_handleMethodCall);
    
    // Отложенная проверка начального файла (после построения UI)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialFile();
    });
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('📥 IncomingFileService: ${call.method}');
    
    switch (call.method) {
      case 'onFileReceived':
        final filePath = call.arguments as String?;
        if (filePath != null) {
          debugPrint('📥 Получен файл: $filePath');
          await _importFile(filePath);
        }
        break;
      case 'onViewIntent':
        final uri = call.arguments as String?;
        if (uri != null) {
          debugPrint('📥 VIEW intent: $uri');
          await _handleUri(uri);
        }
        break;
    }
  }
  
  /// Проверить, был ли файл передан при запуске приложения
  Future<void> _checkInitialFile() async {
    try {
      final filePath = await _channel.invokeMethod<String>('getInitialFile');
      if (filePath != null && filePath.isNotEmpty) {
        debugPrint('📥 Файл при запуске: $filePath');
        // Задержка чтобы UI успел построиться
        await Future.delayed(const Duration(milliseconds: 500));
        await _importFile(filePath);
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка проверки начального файла: $e');
    }
  }
  
  /// Обработать URI (content:// или file://)
  Future<void> _handleUri(String uri) async {
    try {
      // Для content:// URI нужно скопировать содержимое во временный файл
      if (uri.startsWith('content://')) {
        final filePath = await _channel.invokeMethod<String>('copyContentToFile', {'uri': uri});
        if (filePath != null) {
          await _importFile(filePath);
        }
      } else if (uri.startsWith('file://')) {
        await _importFile(uri.replaceFirst('file://', ''));
      } else {
        // Возможно, это уже путь к файлу
        await _importFile(uri);
      }
    } catch (e) {
      debugPrint('❌ Ошибка обработки URI: $e');
    }
  }
  
  /// Импортировать файл
  Future<void> _importFile(String filePath) async {
    debugPrint('📥 Импорт файла: $filePath');
    
    try {
      final result = await _syncService.importFromPath(filePath);
      
      if (onFileReceived != null) {
        onFileReceived!(result);
      }
    } catch (e) {
      debugPrint('❌ Ошибка импорта: $e');
      if (onFileReceived != null) {
        onFileReceived!(ZipImportResult(
          success: false,
          error: e.toString(),
        ));
      }
    }
  }
}
