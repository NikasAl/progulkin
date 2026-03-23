import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_config.dart';
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

  // Переменные для фильтрации выбросов
  WalkPoint? _lastValidPoint;
  int _initialPointsToSkip = 3; // Пропустить первые N точек для стабилизации GPS
  int _pointsReceived = 0;

  // Пороги фильтрации
  static const double _maxWalkingSpeedMps = 5.0; // ~18 км/ч - макс. скорость при прогулке
  static const double _maxAccuracyMeters = 100.0; // Макс. допустимая погрешность
  static const double _maxJumpDistanceMeters = 100.0; // Макс. скачок между точками за 1 сек

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
      if (AppConfig.enableLogging) {
        print('Ошибка получения позиции: $e');
      }
      return null;
    }
  }

  /// Начать отслеживание позиции
  Future<void> startTracking() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      throw Exception('Нет разрешения на геолокацию');
    }

    // Сброс переменных фильтрации
    _lastValidPoint = null;
    _pointsReceived = 0;

    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConfig.trackingDistanceFilter,
      timeLimit: const Duration(seconds: 30),
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        final walkPoint = _positionToWalkPoint(position);
        
        // Фильтрация выбросов
        if (_isValidPoint(walkPoint)) {
          _lastValidPoint = walkPoint;
          _positionController.add(walkPoint);
        } else {
          if (AppConfig.enableLogging) {
            print('Точка отфильтрована как выброс: ${walkPoint.latitude}, ${walkPoint.longitude}');
          }
        }
      },
      onError: (error) {
        if (AppConfig.enableLogging) {
          print('Ошибка отслеживания: $error');
        }
      },
    );
  }

  /// Проверка валидности точки (фильтрация выбросов)
  bool _isValidPoint(WalkPoint point) {
    _pointsReceived++;

    // Пропускаем первые несколько точек для стабилизации GPS
    if (_pointsReceived <= _initialPointsToSkip) {
      if (AppConfig.enableLogging) {
        print('Пропуск начальной точки #$_pointsReceived для стабилизации GPS');
      }
      return false;
    }

    // Проверка точности
    if (point.accuracy > _maxAccuracyMeters) {
      if (AppConfig.enableLogging) {
        print('Точка отклонена: низкая точность ${point.accuracy.toStringAsFixed(1)}м > $_maxAccuracyMeters м');
      }
      return false;
    }

    // Если нет предыдущей точки, принимаем текущую
    if (_lastValidPoint == null) {
      return true;
    }

    // Вычисляем расстояние до предыдущей точки
    final distance = _calculateDistance(
      _lastValidPoint!.latitude, _lastValidPoint!.longitude,
      point.latitude, point.longitude,
    );

    // Вычисляем время между точками
    final timeDiff = point.timestamp.difference(_lastValidPoint!.timestamp).inSeconds;
    if (timeDiff <= 0) {
      return false;
    }

    // Проверка на нереалистичный скачок
    // Разрешаем большой скачок только если прошло много времени
    final maxAllowedDistance = _maxJumpDistanceMeters * math.max(1, timeDiff ~/ 5);
    
    if (distance > maxAllowedDistance) {
      if (AppConfig.enableLogging) {
        print('Точка отклонена: нереалистичный скачок ${distance.toStringAsFixed(1)}м за ${timeDiff}сек (макс: ${maxAllowedDistance}м)');
      }
      return false;
    }

    // Вычисляем скорость
    final speed = distance / timeDiff; // м/с

    // Проверка скорости (игнорируем если скорость из GPS валидна)
    if (speed > _maxWalkingSpeedMps && point.speed > _maxWalkingSpeedMps) {
      if (AppConfig.enableLogging) {
        print('Точка отклонена: нереалистичная скорость ${(speed * 3.6).toStringAsFixed(1)} км/ч');
      }
      return false;
    }

    return true;
  }

  /// Расчёт расстояния между двумя точками (формула Гаверсинуса)
  double _calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371000; // в метрах
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) + 
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * math.pi / 180;

  /// Остановить отслеживание
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _lastValidPoint = null;
    _pointsReceived = 0;
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
