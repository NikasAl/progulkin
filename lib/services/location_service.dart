import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_config.dart';
import '../models/walk_point.dart';

/// Сервис геолокации для трекинга маршрута с продвинутой фильтрацией
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<WalkPoint> _positionController = 
      StreamController<WalkPoint>.broadcast();
  
  /// Поток позиций для подписки
  Stream<WalkPoint> get positionStream => _positionController.stream;

  // Переменные для фильтрации
  WalkPoint? _lastValidPoint;
  final List<WalkPoint> _recentPoints = []; // Для медианного фильтра
  int _pointsReceived = 0;
  int _pointsAccepted = 0;

  // Настройки фильтрации (настраиваемые)
  double maxWalkingSpeedKmh = 10.0; // км/ч - макс. скорость ходьбы
  double maxAccuracyMeters = 50.0; // макс. допустимая погрешность
  bool enableSmoothing = true; // включить сглаживание
  int smoothingWindowSize = 3; // окно для сглаживания

  /// Обновить настройки фильтрации
  void updateSettings({
    double? maxSpeed,
    double? maxAccuracy,
    bool? smoothing,
  }) {
    if (maxSpeed != null) maxWalkingSpeedKmh = maxSpeed;
    if (maxAccuracy != null) maxAccuracyMeters = maxAccuracy;
    if (smoothing != null) enableSmoothing = smoothing;
    print('Настройки: скорость=$maxWalkingSpeedKmh км/ч, точность=$maxAccuracyMeters м');
  }

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

    // Запрашиваем фоновое разрешение
    if (permission == LocationPermission.whileInUse) {
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

      Position? position;
      
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 20),
        );
      } catch (e) {
        print('Не удалось получить позицию: $e');
        return null;
      }

      final walkPoint = _positionToWalkPoint(position);
      print('Позиция: ${walkPoint.latitude.toStringAsFixed(6)}, ${walkPoint.longitude.toStringAsFixed(6)}, точность: ${walkPoint.accuracy.toStringAsFixed(1)}м');
      return walkPoint;
    } catch (e) {
      print('Ошибка: $e');
      return null;
    }
  }

  /// Начать отслеживание позиции
  Future<void> startTracking() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      throw Exception('Нет разрешения на геолокацию');
    }

    // Сброс переменных
    _lastValidPoint = null;
    _recentPoints.clear();
    _pointsReceived = 0;
    _pointsAccepted = 0;

    print('Начинаем отслеживание GPS...');
    print('Настройки: макс.скорость=$maxWalkingSpeedKmh км/ч, макс.точность=$maxAccuracyMeters м');

    // Настройки локации
    late LocationSettings locationSettings;
    
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Идёт запись вашего маршрута',
          notificationTitle: 'Прогулкин',
          notificationIcon: AndroidResource(name: 'ic_launcher'),
          notificationChannelName: 'Запись маршрута',
          setOngoing: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _processPosition(position);
      },
      onError: (error) {
        print('Ошибка GPS: $error');
      },
    );
  }

  /// Обработка новой позиции с фильтрацией
  void _processPosition(Position position) {
    _pointsReceived++;
    final walkPoint = _positionToWalkPoint(position);
    
    if (AppConfig.enableLogging) {
      print('\n--- Точка #$_pointsReceived ---');
      print('Координаты: ${walkPoint.latitude.toStringAsFixed(6)}, ${walkPoint.longitude.toStringAsFixed(6)}');
      print('Точность: ${walkPoint.accuracy.toStringAsFixed(1)}м');
      print('Скорость GPS: ${(walkPoint.speed * 3.6).toStringAsFixed(1)} км/ч');
    }

    // Многоуровневая фильтрация
    final filterResult = _applyFilters(walkPoint);
    
    if (filterResult.accepted && filterResult.point != null) {
      _pointsAccepted++;
      _lastValidPoint = filterResult.point;
      
      // Добавляем в буфер
      _recentPoints.add(filterResult.point!);
      if (_recentPoints.length > 10) {
        _recentPoints.removeAt(0);
      }
      
      _positionController.add(filterResult.point!);
      
      if (AppConfig.enableLogging) {
        print('✓ ПРИНЯТА (принято: $_pointsAccepted из $_pointsReceived)');
      }
    } else {
      if (AppConfig.enableLogging) {
        print('✗ ОТКЛОНЕНА: ${filterResult.reason}');
      }
    }
  }

  /// Применить все фильтры к точке
  _FilterResult _applyFilters(WalkPoint point) {
    // 1. Проверка точности
    if (point.accuracy > maxAccuracyMeters) {
      return _FilterResult(rejected: true, reason: 'Низкая точность ${point.accuracy.toStringAsFixed(1)}м');
    }

    // 2. Проверка скорости из GPS
    final speedKmh = point.speed * 3.6;
    if (speedKmh > maxWalkingSpeedKmh * 1.5) {
      return _FilterResult(rejected: true, reason: 'Скорость GPS ${speedKmh.toStringAsFixed(1)} км/ч');
    }

    // Если нет предыдущей точки
    if (_lastValidPoint == null) {
      if (point.accuracy <= maxAccuracyMeters / 2) {
        return _FilterResult(accepted: true, point: point);
      }
      return _FilterResult(rejected: true, reason: 'Первая точка: точность ${point.accuracy.toStringAsFixed(1)}м');
    }

    // 3. Проверка расстояния и скорости
    final distance = _calculateDistance(
      _lastValidPoint!.latitude, _lastValidPoint!.longitude,
      point.latitude, point.longitude,
    );

    final timeDiff = point.timestamp.difference(_lastValidPoint!.timestamp).inSeconds;
    
    if (timeDiff <= 0) {
      return _FilterResult(rejected: true, reason: 'Некорректное время');
    }

    // Расчётная скорость
    final calculatedSpeed = (distance / timeDiff) * 3.6;

    // 4. Проверка на нереалистичный скачок
    final maxJumpMeters = (maxWalkingSpeedKmh * timeDiff / 3.6) * 1.5;
    
    if (distance > maxJumpMeters) {
      return _FilterResult(
        rejected: true, 
        reason: 'Скачок ${distance.toStringAsFixed(1)}м (ск. ${calculatedSpeed.toStringAsFixed(1)} км/ч)'
      );
    }

    // 5. Проверка расчётной скорости
    if (calculatedSpeed > maxWalkingSpeedKmh) {
      return _FilterResult(
        rejected: true,
        reason: 'Скорость ${calculatedSpeed.toStringAsFixed(1)} км/ч > $maxWalkingSpeedKmh км/ч'
      );
    }

    // 6. Проверка на возврат к старой позиции
    if (_recentPoints.length >= 3) {
      for (int i = 0; i < _recentPoints.length - 2; i++) {
        final oldPoint = _recentPoints[i];
        final distanceToOld = _calculateDistance(
          oldPoint.latitude, oldPoint.longitude,
          point.latitude, point.longitude,
        );
        
        final timeSinceOld = point.timestamp.difference(oldPoint.timestamp).inSeconds;
        
        if (timeSinceOld > 30 && distanceToOld < 10) {
          final distanceFromLast = _calculateDistance(
            _lastValidPoint!.latitude, _lastValidPoint!.longitude,
            point.latitude, point.longitude,
          );
          if (distanceFromLast > 50) {
            return _FilterResult(rejected: true, reason: 'Подозрительный возврат');
          }
        }
      }
    }

    // 7. Опциональное сглаживание
    WalkPoint finalPoint = point;
    if (enableSmoothing && _recentPoints.length >= smoothingWindowSize) {
      final windowPoints = _recentPoints.sublist(
        _recentPoints.length - smoothingWindowSize + 1
      )..add(point);
      
      double sumLat = 0, sumLon = 0;
      for (final p in windowPoints) {
        sumLat += p.latitude;
        sumLon += p.longitude;
      }
      
      finalPoint = WalkPoint(
        latitude: sumLat / windowPoints.length,
        longitude: sumLon / windowPoints.length,
        altitude: point.altitude,
        speed: point.speed,
        accuracy: point.accuracy,
        timestamp: point.timestamp,
      );
    }

    return _FilterResult(accepted: true, point: finalPoint);
  }

  /// Расчёт расстояния между двумя точками
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    
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
    _pointsAccepted = 0;
    print('GPS остановлен. Статистика: принято $_pointsAccepted из $_pointsReceived');
  }

  /// Проверка, активно ли отслеживание
  bool get isTracking => _positionStreamSubscription != null;

  /// Статистика фильтрации
  Map<String, dynamic> get filterStats => {
    'received': _pointsReceived,
    'accepted': _pointsAccepted,
    'rejected': _pointsReceived - _pointsAccepted,
    'acceptanceRate': _pointsReceived > 0 
        ? (_pointsAccepted / _pointsReceived * 100).toStringAsFixed(1) 
        : '0',
  };

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

/// Результат фильтрации
class _FilterResult {
  final bool accepted;
  final bool rejected;
  final WalkPoint? point;
  final String? reason;

  _FilterResult({this.accepted = false, this.rejected = false, this.point, this.reason});
}
