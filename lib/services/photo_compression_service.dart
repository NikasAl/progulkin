import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Сервис сжатия фото в WebP формат для P2P передачи
class PhotoCompressionService {
  static const int maxPhotoWidth = 800;
  static const int maxPhotoHeight = 600;
  static const int webpQuality = 80;
  static const int maxPhotoSizeKB = 100;

  final Uuid _uuid = const Uuid();

  /// Сжать изображение в WebP формат
  Future<PhotoCompressionResult> compressToWebP({
    required String sourcePath,
    int maxWidth = maxPhotoWidth,
    int maxHeight = maxPhotoHeight,
    int quality = webpQuality,
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

      // Кодируем в WebP
      final webpBytes = img.encodeWebP(resized, level: quality);

      // Генерируем ID
      final photoId = _uuid.v4();

      return PhotoCompressionResult(
        success: true,
        photoId: photoId,
        webpBytes: webpBytes,
        width: newWidth,
        height: newHeight,
        sizeBytes: webpBytes.length,
      );
    } catch (e) {
      return PhotoCompressionResult(
        success: false,
        error: 'Ошибка сжатия: $e',
      );
    }
  }

  /// Сжать изображение из байтов
  Future<PhotoCompressionResult> compressBytesToWebP({
    required Uint8List bytes,
    int maxWidth = maxPhotoWidth,
    int maxHeight = maxPhotoHeight,
    int quality = webpQuality,
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

      // Кодируем в WebP
      final webpBytes = img.encodeWebP(resized, level: quality);

      final photoId = _uuid.v4();

      return PhotoCompressionResult(
        success: true,
        photoId: photoId,
        webpBytes: Uint8List.fromList(webpBytes),
        width: newWidth,
        height: newHeight,
        sizeBytes: webpBytes.length,
      );
    } catch (e) {
      return PhotoCompressionResult(
        success: false,
        error: 'Ошибка сжатия: $e',
      );
    }
  }

  /// Декодировать WebP в байты для отображения
  Future<Uint8List?> decodeWebP(Uint8List webpBytes) async {
    try {
      final image = img.decodeWebP(webpBytes);
      if (image == null) return null;

      // Кодируем в PNG для отображения в Flutter
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      return null;
    }
  }

  /// Сохранить WebP во временный файл
  Future<String?> saveToTempFile(Uint8List webpBytes, String photoId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$photoId.webp');
      await file.writeAsBytes(webpBytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Создать превью (миниатюру)
  Future<PhotoCompressionResult> createThumbnail({
    required Uint8List webpBytes,
    int size = 200,
  }) async {
    try {
      final image = img.decodeWebP(webpBytes);
      if (image == null) {
        return PhotoCompressionResult(
          success: false,
          error: 'Не удалось декодировать WebP',
        );
      }

      // Создаём квадратную миниатюру
      final thumbnail = img.copyResize(
        image,
        width: size,
        height: size,
        interpolation: img.Interpolation.linear,
      );

      final thumbnailBytes = img.encodeWebP(thumbnail, level: 60);

      return PhotoCompressionResult(
        success: true,
        photoId: '${_uuid.v4()}_thumb',
        webpBytes: Uint8List.fromList(thumbnailBytes),
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
  final Uint8List? webpBytes;
  final int? width;
  final int? height;
  final int? sizeBytes;
  final String? error;

  const PhotoCompressionResult({
    required this.success,
    this.photoId,
    this.webpBytes,
    this.width,
    this.height,
    this.sizeBytes,
    this.error,
  });

  double? get sizeInKB => sizeBytes != null ? sizeBytes! / 1024 : null;
  bool get isWithinLimit =>
      sizeBytes != null && sizeBytes! <= PhotoCompressionService.maxPhotoSizeKB * 1024;
}
