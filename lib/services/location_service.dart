import 'dart:async';
import 'dart:io';
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
  final List<WalkPoint> _recentPoints = []; // Для усреднения
  int _pointsReceived = 0;
  DateTime? _trackingStartTime;

  // Пороги фильтрации (более строгие)
  static const double _maxWalkingSpeedMps = 2.5; // ~9 км/ч - реальная скорость при ходьбе
  static const double _maxAccuracyMeters = 30.0; // Более строгий порог точности
  static const int _minPointsForAverage = 3; // Мин. точек для усреднения
  static const int _maxRecentPoints = 5; // Храним последние N точек
  static const Duration _gpsStabilizationTime = Duration(seconds: 30); // Время стабилизации GPS

  /// Проверка разрешений на геолокацию
  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('GPS сервис отключён');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    print('Текущее разрешение: $permission');
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      print('Запрошено разрешение, результат: $permission');
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await openAppSettings();
      return false;
    }

    // Проверяем разрешение на фоновую геолокацию
    if (permission == LocationPermission.whileInUse) {
      print('Разрешение только при использовании - запрашиваем фоновое');
      // На Android 10+ нужно отдельно запросить фоновое разрешение
      final backgroundStatus = await Permission.locationAlways.status;
      if (backgroundStatus.isDenied) {
        await Permission.locationAlways.request();
      }
    }

    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  /// Получить текущую позицию
  Future<WalkPoint?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) return null;

      // Делаем несколько попыток с разной точностью
      Position? position;
      
      // Сначала пробуем высокую точность
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 20),
        );
      } catch (e) {
        print('Не удалось получить позицию с лучшей точностью: $e');
        // Fallback на среднюю точность
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (e2) {
          print('Не удалось получить позицию: $e2');
          return null;
        }
      }

      final walkPoint = _positionToWalkPoint(position);
      print('Получена позиция: ${walkPoint.latitude.toStringAsFixed(6)}, ${walkPoint.longitude.toStringAsFixed(6)}, точность: ${walkPoint.accuracy.toStringAsFixed(1)}м');
      return walkPoint;
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

    // Сброс переменных фильтрации
    _lastValidPoint = null;
    _recentPoints.clear();
    _pointsReceived = 0;
    _trackingStartTime = DateTime.now();

    print('Начинаем отслеживание GPS...');

    // Настройки локации
    late LocationSettings locationSettings;
    
    if (Platform.isAndroid) {
      // Android: используем foreground service для работы в фоне
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0, // Получаем все обновления, фильтруем сами
        intervalDuration: const Duration(seconds: 2), // Обновление каждые 2 секунды
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Идёт запись вашего маршрута',
          notificationTitle: 'Прогулкин',
          notificationIcon: AndroidResource(name: 'ic_launcher'),
          notificationChannelName: 'Запись маршрута',
          notificationPriority: Priority.low,
          setOngoing: true,
        ),
      );
    } else {
      // iOS
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        timeInterval: 2000,
      );
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _pointsReceived++;
        final walkPoint = _positionToWalkPoint(position);
        
        if (AppConfig.enableLogging) {
          print('Точка #$_pointsReceived: ${walkPoint.latitude.toStringAsFixed(6)}, ${walkPoint.longitude.toStringAsFixed(6)}, accuracy: ${walkPoint.accuracy.toStringAsFixed(1)}м, speed: ${(walkPoint.speed * 3.6).toStringAsFixed(1)} км/ч');
        }
        
        // Фильтрация выбросов
        if (_isValidPoint(walkPoint)) {
          _lastValidPoint = walkPoint;
          _addToRecentPoints(walkPoint);
          _positionController.add(walkPoint);
          print('✓ Точка принята');
        } else {
          print('✗ Точка отфильтрована');
        }
      },
      onError: (error) {
        print('Ошибка отслеживания GPS: $error');
      },
    );
  }

  /// Добавить точку в список недавних (для усреднения)
  void _addToRecentPoints(WalkPoint point) {
    _recentPoints.add(point);
    if (_recentPoints.length > _maxRecentPoints) {
      _recentPoints.removeAt(0);
    }
  }

  /// Проверка валидности точки (фильтрация выбросов)
  bool _isValidPoint(WalkPoint point) {
    // Период стабилизации GPS (первые 30 секунд игнорируем все точки кроме первой)
    if (_trackingStartTime != null) {
      final timeSinceStart = DateTime.now().difference(_trackingStartTime!);
      if (timeSinceStart < _gpsStabilizationTime && _lastValidPoint == null) {
        // Принимаем первую точку с хорошей точностью
        if (point.accuracy <= _maxAccuracyMeters) {
          print('Принята начальная точка в период стабилизации');
          return true;
        }
        return false;
      }
    }

    // Строгая проверка точности
    if (point.accuracy > _maxAccuracyMeters) {
      print('Отклонено: низкая точность ${point.accuracy.toStringAsFixed(1)}м > ${_maxAccuracyMeters}м');
      return false;
    }

    // Проверка скорости из GPS (если доступна)
    if (point.speed > _maxWalkingSpeedMps * 1.5) {
      print('Отклонено: высокая скорость GPS ${(point.speed * 3.6).toStringAsFixed(1)} км/ч');
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

    // Вычисляем скорость
    final calculatedSpeed = distance / timeDiff; // м/с

    // Строгая проверка скорости
    if (calculatedSpeed > _maxWalkingSpeedMps) {
      print('Отклонено: нереалистичная скорость ${(calculatedSpeed * 3.6).toStringAsFixed(1)} км/ч (дистанция: ${distance.toStringAsFixed(1)}м за ${timeDiff}сек)');
      return false;
    }

    // Проверка на нереалистичный скачок
    // При ходьбе 2 м/с за 2 сек максимум ~4м, но даём запас до 10м
    final maxJump = math.max(10.0, _maxWalkingSpeedMps * timeDiff * 2);
    if (distance > maxJump) {
      print('Отклонено: нереалистичный скачок ${distance.toStringAsFixed(1)}м (макс: ${maxJump.toStringAsFixed(1)}м)');
      return false;
    }

    // Проверка на "дрожание" GPS (точки прыгают туда-сюда)
    if (_recentPoints.length >= 3) {
      final avgDistance = _calculateAverageDistanceFromRecent(point);
      if (avgDistance > distance * 2) {
        print('Отклонено: похоже на дрожание GPS');
        return false;
      }
    }

    return true;
  }

  /// Вычислить среднее расстояние от недавних точек
  double _calculateAverageDistanceFromRecent(WalkPoint newPoint) {
    if (_recentPoints.isEmpty) return 0;
    
    double totalDistance = 0;
    for (final point in _recentPoints) {
      totalDistance += _calculateDistance(
        point.latitude, point.longitude,
        newPoint.latitude, newPoint.longitude,
      );
    }
    return totalDistance / _recentPoints.length;
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
    _recentPoints.clear();
    _pointsReceived = 0;
    _trackingStartTime = null;
    print('Отслеживание GPS остановлено');
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
