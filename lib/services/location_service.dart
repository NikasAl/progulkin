import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/walk_point.dart';

/// Сервис геолокации для трекинга маршрута
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<WalkPoint> _positionController = 
      StreamController<WalkPoint>.broadcast();
  
  /// Поток позиций для подписки
  Stream<WalkPoint> get positionStream => _positionController.stream;

  /// Проверка разрешений на геолокацию
  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await openAppSettings();
      return false;
    }

    return true;
  }

  /// Получить текущую позицию
  Future<WalkPoint?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return _positionToWalkPoint(position);
    } catch (e) {
      print('Ошибка получения позиции: $e');
      return null;
    }
  }

  /// Начать отслеживание позиции
  Future<void> startTracking() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      throw Exception('Нет разрешения на геолокацию');
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Обновление каждые 5 метров
      timeLimit: Duration(seconds: 30),
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        final walkPoint = _positionToWalkPoint(position);
        _positionController.add(walkPoint);
      },
      onError: (error) {
        print('Ошибка отслеживания: $error');
      },
    );
  }

  /// Остановить отслеживание
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Проверка, активно ли отслеживание
  bool get isTracking => _positionStreamSubscription != null;

  /// Преобразование Position в WalkPoint
  WalkPoint _positionToWalkPoint(Position position) {
    return WalkPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: position.speed,
      accuracy: position.accuracy,
      timestamp: position.timestamp ?? DateTime.now(),
    );
  }

  /// Освобождение ресурсов
  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
