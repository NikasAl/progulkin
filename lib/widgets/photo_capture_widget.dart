import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/location_service.dart';
import '../services/photo_compression_service.dart';
import '../config/constants.dart';
import '../models/map_objects/map_object.dart';

/// Результат съёмки фото
class PhotoCaptureResult {
  final Uint8List bytes;
  final String id;
  final Map<String, dynamic> metadata;

  const PhotoCaptureResult({
    required this.bytes,
    required this.id,
    required this.metadata,
  });
}

/// Виджет для съёмки фото с GPS-верификацией
///
/// Используется при создании объектов (TrashMonster, InterestNote)
/// для прикрепления фотографий с подтверждением местоположения.
class PhotoCaptureWidget extends StatefulWidget {
  /// Координаты целевого места (для проверки расстояния)
  final double targetLatitude;
  final double targetLongitude;

  /// Список уже добавленных фото
  final List<PhotoCaptureResult> photos;

  /// Callback при добавлении нового фото
  final void Function(PhotoCaptureResult photo) onPhotoAdded;

  /// Callback при удалении фото
  final void Function(int index) onPhotoRemoved;

  /// Максимальное количество фото
  final int maxPhotos;

  /// Радиус верификации (метры)
  final double verificationRadius;

  /// Показывать ли подсказку о GPS-верификации
  final bool showHint;

  const PhotoCaptureWidget({
    super.key,
    required this.targetLatitude,
    required this.targetLongitude,
    required this.photos,
    required this.onPhotoAdded,
    required this.onPhotoRemoved,
    this.maxPhotos = AppConstants.maxPhotosPerObject,
    this.verificationRadius = AppConstants.photoVerificationRadius,
    this.showHint = true,
  });

  @override
  State<PhotoCaptureWidget> createState() => _PhotoCaptureWidgetState();
}

class _PhotoCaptureWidgetState extends State<PhotoCaptureWidget> {
  final _locationService = LocationService();
  final _photoCompressionService = PhotoCompressionService();
  final _imagePicker = ImagePicker();
  bool _isCapturing = false;

  Future<void> _takePhoto() async {
    if (widget.photos.length >= widget.maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Максимум ${widget.maxPhotos} фото'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCapturing = true);

    try {
      // Проверяем текущую позицию пользователя
      final currentPosition = await _locationService.getCurrentPosition();
      if (currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось определить ваше местоположение'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Проверяем расстояние до целевого места
      final distance = calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        widget.targetLatitude,
        widget.targetLongitude,
      );

      if (distance > widget.verificationRadius) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Вы слишком далеко от места (${distance.toInt()} м). Подойдите ближе.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Открываем камеру
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: AppConstants.cameraMaxWidth.toDouble(),
        maxHeight: AppConstants.cameraMaxHeight.toDouble(),
        imageQuality: AppConstants.cameraQuality,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();

        // Сжимаем фото
        final compressed = await _photoCompressionService.compressBytes(
          bytes: bytes,
        );

        if (compressed.success && compressed.compressedBytes != null) {
          final result = PhotoCaptureResult(
            bytes: compressed.compressedBytes!,
            id: compressed.photoId!,
            metadata: {
              'latitude': currentPosition.latitude,
              'longitude': currentPosition.longitude,
              'distance': distance,
              'timestamp': DateTime.now().toIso8601String(),
              'verified': distance <= widget.verificationRadius,
            },
          );
          widget.onPhotoAdded(result);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при съёмке фото: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок и кнопка
        Row(
          children: [
            Text(
              'Фото',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (_isCapturing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton.icon(
                onPressed: widget.photos.length >= widget.maxPhotos ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Снять фото'),
              ),
          ],
        ),

        // Подсказка
        if (widget.showHint) ...[
          const SizedBox(height: 4),
          Text(
            'Фото можно сделать только здесь и сейчас',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],

        const SizedBox(height: 8),

        // Список фото
        if (widget.photos.isNotEmpty)
          SizedBox(
            height: UIConstants.photoListSize,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.photos.length,
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                final isVerified = photo.metadata['verified'] as bool? ?? false;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      // Изображение
                      ClipRRect(
                        borderRadius: BorderRadius.circular(UIConstants.photoBorderRadius),
                        child: Image.memory(
                          photo.bytes,
                          height: UIConstants.photoListSize,
                          width: UIConstants.photoListSize,
                          fit: BoxFit.cover,
                        ),
                      ),

                      // Индикатор verified location
                      if (isVerified)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, size: 10, color: Colors.white),
                                SizedBox(width: 2),
                                Text(
                                  'Здесь',
                                  style: TextStyle(fontSize: 8, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Кнопка удаления
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => widget.onPhotoRemoved(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Счётчик фото
        if (widget.maxPhotos > 1 && widget.photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${widget.photos.length} / ${widget.maxPhotos}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }
}
