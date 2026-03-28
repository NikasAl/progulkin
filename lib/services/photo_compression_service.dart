import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Сервис сжатия фото для P2P передачи
/// Использует JPEG для совместимости (WebP может не поддерживаться в image 4.x)
class PhotoCompressionService {
  static const int maxPhotoWidth = 800;
  static const int maxPhotoHeight = 600;
  static const int jpegQuality = 85;
  static const int maxPhotoSizeKB = 100;

  final Uuid _uuid = const Uuid();

  /// Сжать изображение в формат (JPEG для совместимости)
  Future<PhotoCompressionResult> compress({
    required String sourcePath,
    int maxWidth = maxPhotoWidth,
    int maxHeight = maxPhotoHeight,
    int quality = jpegQuality,
  }) async {
    try {
      // Читаем исходное изображение
      final file = File(sourcePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        return PhotoCompressionResult(
          success: false,
          error: 'Не удалось декодировать изображение',
        );
      }

      // Вычисляем новые размеры с сохранением пропорций
      int newWidth = image.width;
      int newHeight = image.height;

      if (newWidth > maxWidth || newHeight > maxHeight) {
        final widthRatio = maxWidth / newWidth;
        final heightRatio = maxHeight / newHeight;
        final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;

        newWidth = (newWidth * ratio).round();
        newHeight = (newHeight * ratio).round();
      }

      // Изменяем размер
      img.Image resized;
      if (newWidth != image.width || newHeight != image.height) {
        resized = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resized = image;
      }

      // Кодируем в JPEG
      final compressedBytes = img.encodeJpg(resized, quality: quality);

      // Генерируем ID
      final photoId = _uuid.v4();

      return PhotoCompressionResult(
        success: true,
        photoId: photoId,
        compressedBytes: Uint8List.fromList(compressedBytes),
        width: newWidth,
        height: newHeight,
        sizeBytes: compressedBytes.length,
      );
    } catch (e) {
      return PhotoCompressionResult(
        success: false,
        error: 'Ошибка сжатия: $e',
      );
    }
  }

  /// Сжать изображение из байтов
  Future<PhotoCompressionResult> compressBytes({
    required Uint8List bytes,
    int maxWidth = maxPhotoWidth,
    int maxHeight = maxPhotoHeight,
    int quality = jpegQuality,
  }) async {
    try {
      final image = img.decodeImage(bytes);

      if (image == null) {
        return PhotoCompressionResult(
          success: false,
          error: 'Не удалось декодировать изображение',
        );
      }

      // Вычисляем новые размеры
      int newWidth = image.width;
      int newHeight = image.height;

      if (newWidth > maxWidth || newHeight > maxHeight) {
        final widthRatio = maxWidth / newWidth;
        final heightRatio = maxHeight / newHeight;
        final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;

        newWidth = (newWidth * ratio).round();
        newHeight = (newHeight * ratio).round();
      }

      // Изменяем размер
      img.Image resized;
      if (newWidth != image.width || newHeight != image.height) {
        resized = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resized = image;
      }

      // Кодируем в JPEG
      final compressedBytes = img.encodeJpg(resized, quality: quality);

      final photoId = _uuid.v4();

      return PhotoCompressionResult(
        success: true,
        photoId: photoId,
        compressedBytes: Uint8List.fromList(compressedBytes),
        width: newWidth,
        height: newHeight,
        sizeBytes: compressedBytes.length,
      );
    } catch (e) {
      return PhotoCompressionResult(
        success: false,
        error: 'Ошибка сжатия: $e',
      );
    }
  }

  /// Декодировать изображение в байты для отображения
  Future<Uint8List?> decode(Uint8List compressedBytes) async {
    try {
      final image = img.decodeImage(compressedBytes);
      if (image == null) return null;

      // Кодируем в PNG для отображения в Flutter
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      return null;
    }
  }

  /// Сохранить во временный файл
  Future<String?> saveToTempFile(Uint8List bytes, String photoId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$photoId.jpg');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Создать превью (миниатюру)
  Future<PhotoCompressionResult> createThumbnail({
    required Uint8List imageBytes,
    int size = 200,
  }) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return PhotoCompressionResult(
          success: false,
          error: 'Не удалось декодировать изображение',
        );
      }

      // Создаём квадратную миниатюру
      final thumbnail = img.copyResize(
        image,
        width: size,
        height: size,
        interpolation: img.Interpolation.linear,
      );

      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 70);

      return PhotoCompressionResult(
        success: true,
        photoId: '${_uuid.v4()}_thumb',
        compressedBytes: Uint8List.fromList(thumbnailBytes),
        width: size,
        height: size,
        sizeBytes: thumbnailBytes.length,
      );
    } catch (e) {
      return PhotoCompressionResult(
        success: false,
        error: 'Ошибка создания превью: $e',
      );
    }
  }

  /// Проверить, соответствует ли фото размеру
  bool isWithinSizeLimit(int sizeBytes, {int maxSizeKB = maxPhotoSizeKB}) {
    return sizeBytes <= maxSizeKB * 1024;
  }

  /// Получить размер в KB
  double sizeInKB(int sizeBytes) {
    return sizeBytes / 1024;
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
}
