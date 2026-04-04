import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';

/// Сервис сжатия фото для P2P передачи
/// Использует нативный WebP через flutter_image_compress для лучшего сжатия
class PhotoCompressionService {
  /// Алиасы к константам для обратной совместимости
  static int get maxPhotoWidth => AppConstants.maxPhotoWidth;
  static int get maxPhotoHeight => AppConstants.maxPhotoHeight;
  static int get webpQuality => AppConstants.webpQuality;
  static int get maxPhotoSizeKB => AppConstants.maxPhotoSizeKB;
  static int get maxOriginalSizeKB => AppConstants.maxOriginalSizeKB;

  final Uuid _uuid = const Uuid();

  /// Сжать изображение из файла в WebP
  Future<PhotoCompressionResult> compress({
    required String sourcePath,
    int maxWidth = AppConstants.maxPhotoWidth,
    int maxHeight = AppConstants.maxPhotoHeight,
    int quality = AppConstants.webpQuality,
  }) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        return PhotoCompressionResult(
          success: false,
          error: 'Файл не найден: $sourcePath',
        );
      }

      // Получаем размеры оригинала
      final originalBytes = await file.readAsBytes();
      final imageData = await _getImageDimensions(originalBytes);
      
      // Вычисляем новые размеры с сохранением пропорций
      int? newWidth;
      int? newHeight;
      
      if (imageData != null) {
        final (origWidth, origHeight) = imageData;
        if (origWidth > maxWidth || origHeight > maxHeight) {
          final widthRatio = maxWidth / origWidth;
          final heightRatio = maxHeight / origHeight;
          final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;
          newWidth = (origWidth * ratio).round();
          newHeight = (origHeight * ratio).round();
        }
      }

      // Сжимаем в WebP
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: newWidth ?? maxWidth,
        minHeight: newHeight ?? maxHeight,
        quality: quality,
        format: CompressFormat.webp,
        keepExif: false,
      );

      if (result == null) {
        return PhotoCompressionResult(
          success: false,
          error: 'Не удалось сжать изображение',
        );
      }

      final photoId = _uuid.v4();
      final compressedBytes = Uint8List.fromList(result);

      // Получаем размеры сжатого изображения
      final compressedDimensions = await _getImageDimensions(compressedBytes);

      return PhotoCompressionResult(
        success: true,
        photoId: photoId,
        compressedBytes: compressedBytes,
        width: compressedDimensions?.$1 ?? newWidth ?? maxWidth,
        height: compressedDimensions?.$2 ?? newHeight ?? maxHeight,
        sizeBytes: compressedBytes.length,
      );
    } catch (e) {
      debugPrint('PhotoCompressionService: Ошибка сжатия: $e');
      return PhotoCompressionResult(
        success: false,
        error: 'Ошибка сжатия: $e',
      );
    }
  }

  /// Сжать изображение из байтов в WebP
  Future<PhotoCompressionResult> compressBytes({
    required Uint8List bytes,
    int maxWidth = AppConstants.maxPhotoWidth,
    int maxHeight = AppConstants.maxPhotoHeight,
    int quality = AppConstants.webpQuality,
  }) async {
    try {
      // Получаем размеры оригинала
      final imageData = await _getImageDimensions(bytes);
      
      int? newWidth;
      int? newHeight;
      
      if (imageData != null) {
        final (origWidth, origHeight) = imageData;
        if (origWidth > maxWidth || origHeight > maxHeight) {
          final widthRatio = maxWidth / origWidth;
          final heightRatio = maxHeight / origHeight;
          final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;
          newWidth = (origWidth * ratio).round();
          newHeight = (origHeight * ratio).round();
        }
      }

      // Сжимаем в WebP
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: newWidth ?? maxWidth,
        minHeight: newHeight ?? maxHeight,
        quality: quality,
        format: CompressFormat.webp,
        keepExif: false,
      );

      final photoId = _uuid.v4();
      final compressedBytes = Uint8List.fromList(result);

      // Получаем размеры сжатого изображения
      final compressedDimensions = await _getImageDimensions(compressedBytes);

      return PhotoCompressionResult(
        success: true,
        photoId: photoId,
        compressedBytes: compressedBytes,
        width: compressedDimensions?.$1 ?? newWidth ?? maxWidth,
        height: compressedDimensions?.$2 ?? newHeight ?? maxHeight,
        sizeBytes: compressedBytes.length,
      );
    } catch (e) {
      debugPrint('PhotoCompressionService: Ошибка сжатия байтов: $e');
      return PhotoCompressionResult(
        success: false,
        error: 'Ошибка сжатия: $e',
      );
    }
  }

  /// Сжать оригинальное фото для хранения (больше размер, выше качество)
  Future<PhotoCompressionResult> compressOriginal({
    required String sourcePath,
    int quality = AppConstants.webpOriginalQuality,
  }) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        return PhotoCompressionResult(
          success: false,
          error: 'Файл не найден: $sourcePath',
        );
      }

      // Сжимаем в WebP без изменения размера
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: quality,
        format: CompressFormat.webp,
        keepExif: false,
      );

      if (result == null) {
        return PhotoCompressionResult(
          success: false,
          error: 'Не удалось сжать изображение',
        );
      }

      final photoId = _uuid.v4();
      final compressedBytes = Uint8List.fromList(result);
      
      // Получаем размеры
      final dimensions = await _getImageDimensions(compressedBytes);

      return PhotoCompressionResult(
        success: true,
        photoId: photoId,
        compressedBytes: compressedBytes,
        width: dimensions?.$1 ?? 0,
        height: dimensions?.$2 ?? 0,
        sizeBytes: compressedBytes.length,
      );
    } catch (e) {
      debugPrint('PhotoCompressionService: Ошибка сжатия оригинала: $e');
      return PhotoCompressionResult(
        success: false,
        error: 'Ошибка сжатия: $e',
      );
    }
  }

  /// Создать превью (миниатюру) для списка
  Future<PhotoCompressionResult> createThumbnail({
    required Uint8List imageBytes,
    int size = AppConstants.thumbnailSize,
    int quality = AppConstants.thumbnailQuality,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: size,
        minHeight: size,
        quality: quality,
        format: CompressFormat.webp,
        keepExif: false,
      );

      final photoId = '${_uuid.v4()}_thumb';
      final compressedBytes = Uint8List.fromList(result);

      return PhotoCompressionResult(
        success: true,
        photoId: photoId,
        compressedBytes: compressedBytes,
        width: size,
        height: size,
        sizeBytes: compressedBytes.length,
      );
    } catch (e) {
      debugPrint('PhotoCompressionService: Ошибка создания превью: $e');
      return PhotoCompressionResult(
        success: false,
        error: 'Ошибка создания превью: $e',
      );
    }
  }

  /// Получить размеры изображения
  Future<(int, int)?> _getImageDimensions(Uint8List bytes) async {
    // К сожалению, flutter_image_compress не возвращает размеры напрямую
    // Будет определено позже при необходимости
    return null;
  }

  /// Сохранить во временный файл
  Future<String?> saveToTempFile(Uint8List bytes, String photoId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$photoId.webp');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('PhotoCompressionService: Ошибка сохранения: $e');
      return null;
    }
  }

  /// Проверить, соответствует ли фото размеру
  bool isWithinSizeLimit(int sizeBytes, {int? maxSizeKB}) {
    final limit = maxSizeKB ?? maxPhotoSizeKB;
    return sizeBytes <= limit * 1024;
  }

  /// Получить размер в KB
  double sizeInKB(int sizeBytes) {
    return sizeBytes / 1024;
  }

  /// Форматировать размер для отображения
  String formatSize(int sizeBytes) {
    if (sizeBytes < 1024) return '$sizeBytes Б';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} КБ';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
}

/// Результат сжатия фото
class PhotoCompressionResult {
  final bool success;
  final String? photoId;
  final Uint8List? compressedBytes;
  final int? width;
  final int? height;
  final int? sizeBytes;
  final String? error;

  const PhotoCompressionResult({
    required this.success,
    this.photoId,
    this.compressedBytes,
    this.width,
    this.height,
    this.sizeBytes,
    this.error,
  });

  double? get sizeInKB => sizeBytes != null ? sizeBytes! / 1024 : null;
  
  bool get isWithinLimit =>
      sizeBytes != null && sizeBytes! <= PhotoCompressionService.maxPhotoSizeKB * 1024;
  
  bool get isWithinOriginalLimit =>
      sizeBytes != null && sizeBytes! <= PhotoCompressionService.maxOriginalSizeKB * 1024;
  
  String? get formattedSize => sizeBytes != null 
      ? PhotoCompressionService().formatSize(sizeBytes!) 
      : null;
}
