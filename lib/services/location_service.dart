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
  final List<WalkPoint> _pendingPoints = []; // Буфер для сглаживания
  int _pointsReceived = 0;
  int _pointsAccepted = 0;
  DateTime? _trackingStartTime;

  // Настройки фильтрации (можно вынести в настройки приложения)
  double maxWalkingSpeedKmh = 10.0; // км/ч - макс. скорость ходьбы (настраивается)
  double maxAccuracyMeters = 50.0; // макс. допустимая погрешность
  int medianFilterSize = 5; // размер окна медианного фильтра
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
    print('Настройки фильтрации: скорость=$maxWalkingSpeedKmh км/ч, точность=$maxAccuracyMeters м');
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
        print('Не удалось получить позицию с лучшей точностью: $e');
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

    // Сброс переменных
    _lastValidPoint = null;
    _recentPoints.clear();
    _pendingPoints.clear();
    _pointsReceived = 0;
    _pointsAccepted = 0;
    _trackingStartTime = DateTime.now();

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
          notificationPriority: Priority.low,
          setOngoing: true,
        ),
      );
    } else {
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
        _processPosition(position);
      },
      onError: (error) {
        print('Ошибка отслеживания GPS: $error');
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
    
    if (filterResult.isAccepted) {
      _pointsAccepted++;
      _lastValidPoint = filterResult.point;
      
      // Добавляем в буфер для медианного фильтра
      _addToBuffer(_recentPoints, walkPoint, medianFilterSize);
      
      _positionController.add(filterResult.point);
      
      if (AppConfig.enableLogging) {
        print('✓ ТОЧКА ПРИНЯТА (принято: $_pointsAccepted из $_pointsReceived)');
      }
    } else {
      if (AppConfig.enableLogging) {
        print('✗ ТОЧКА ОТКЛОНЕНА: ${filterResult.reason}');
      }
    }
  }

  /// Применить все фильтры к точке
  _FilterResult _applyFilters(WalkPoint point) {
    // 1. Проверка точности
    if (point.accuracy > maxAccuracyMeters) {
      return _FilterResult(rejected: true, reason: 'Низкая точность ${point.accuracy.toStringAsFixed(1)}м > $maxAccuracyMeters м');
    }

    // 2. Проверка скорости из GPS (если доступна и валидна)
    if (point.speed > 0) {
      final speedKmh = point.speed * 3.6;
      if (speedKmh > maxWalkingSpeedKmh * 1.5) {
        return _FilterResult(rejected: true, reason: 'Скорость GPS ${speedKmh.toStringAsFixed(1)} км/ч слишком высока');
      }
    }

    // Если нет предыдущей точки - принимаем с осторожностью
    if (_lastValidPoint == null) {
      // Для первой точки требуем лучшую точность
      if (point.accuracy <= maxAccuracyMeters / 2) {
        return _FilterResult(accepted: true, point: point);
      }
      return _FilterResult(rejected: true, reason: 'Первая точка: низкая точность ${point.accuracy.toStringAsFixed(1)}м');
    }

    // 3. Проверка расстояния и скорости между точками
    final distance = _calculateDistance(
      _lastValidPoint!.latitude, _lastValidPoint!.longitude,
      point.latitude, point.longitude,
    );

    final timeDiff = point.timestamp.difference(_lastValidPoint!.timestamp).inSeconds;
    
    if (timeDiff <= 0) {
      return _FilterResult(rejected: true, reason: 'Некорректное время');
    }

    // Расчётная скорость
    final calculatedSpeed = (distance / timeDiff) * 3.6; // км/ч

    // 4. Проверка на нереалистичный скачок
    // При скорости X км/ч за Y сек макс. расстояние = X * Y / 3.6 м
    final maxJumpMeters = (maxWalkingSpeedKmh * timeDiff / 3.6) * 1.5; // +50% запас
    
    if (distance > maxJumpMeters) {
      return _FilterResult(
        rejected: true, 
        reason: 'Скачок ${distance.toStringAsFixed(1)}м > макс ${maxJumpMeters.toStringAsFixed(1)}м (скорость ${calculatedSpeed.toStringAsFixed(1)} км/ч)'
      );
    }

    // 5. Проверка расчётной скорости
    if (calculatedSpeed > maxWalkingSpeedKmh) {
      return _FilterResult(
        rejected: true,
        reason: 'Скорость ${calculatedSpeed.toStringAsFixed(1)} км/ч > $maxWalkingSpeedKmh км/ч'
      );
    }

    // 6. Проверка на "возврат" к старой позиции (характерно для GPS выбросов)
    if (_recentPoints.length >= 3) {
      final returnCheck = _checkReturnToOldPosition(point);
      if (returnCheck != null) {
        return _FilterResult(rejected: true, reason: returnCheck);
      }
    }

    // 7. Медианный фильтр для выявления выбросов
    if (_recentPoints.length >= 3) {
      final medianCheck = _medianFilterCheck(point);
      if (medianCheck != null) {
        return _FilterResult(rejected: true, reason: medianCheck);
      }
    }

    // 8. Опциональное сглаживание
    WalkPoint finalPoint = point;
    if (enableSmoothing && _recentPoints.length >= smoothingWindowSize) {
      finalPoint = _smoothPoint(point);
    }

    return _FilterResult(accepted: true, point: finalPoint);
  }

  /// Проверка на возврат к старой позиции (характерно для GPS выбросов)
  String? _checkReturnToOldPosition(WalkPoint point) {
    // Проверяем, не возвращаемся ли мы к позиции, где были давно
    for (int i = 0; i < _recentPoints.length - 2; i++) {
      final oldPoint = _recentPoints[i];
      final distanceToOld = _calculateDistance(
        oldPoint.latitude, oldPoint.longitude,
        point.latitude, point.longitude,
      );
      
      final timeSinceOld = point.timestamp.difference(oldPoint.timestamp).inSeconds;
      
      // Если мы "вернулись" к позиции где были более 30 сек назад
      // но расстояние от последней точки большое - это выброс
      if (timeSinceOld > 30 && distanceToOld < 10) {
        final distanceFromLast = _calculateDistance(
          _lastValidPoint!.latitude, _lastValidPoint!.longitude,
          point.latitude, point.longitude,
        );
        if (distanceFromLast > 50) {
          return 'Подозрительный возврат к старой позиции';
        }
      }
    }
    return null;
  }

  /// Медианный фильтр для выявления выбросов
  String? _medianFilterCheck(WalkPoint point) {
    // Вычисляем медианное расстояние от последних точек
    final distances = <double>[];
    for (final recentPoint in _recentPoints) {
      distances.add(_calculateDistance(
        recentPoint.latitude, recentPoint.longitude,
        point.latitude, point.longitude,
      ));
    }
    distances.sort();
    final medianDistance = distances[distances.length ~/ 2];
    
    // Если медианное расстояние очень отличается от расстояния до последней точки
    final lastDistance = distances.last;
    if (lastDistance > medianDistance * 3 && medianDistance > 5) {
      return 'Медианный фильтр: аномальное смещение';
    }
    
    return null;
  }

  /// Сглаживание точки (скользящее среднее)
  WalkPoint _smoothPoint(WalkPoint point) {
    final windowPoints = _recentPoints.sublist(
      _recentPoints.length - smoothingWindowSize + 1
    )..add(point);
    
    double sumLat = 0, sumLon = 0, sumAlt = 0;
    double sumSpeed = 0, sumAccuracy = 0;
    
    for (final p in windowPoints) {
      sumLat += p.latitude;
      sumLon += p.longitude;
      sumAlt += p.altitude;
      sumSpeed += p.speed;
      sumAccuracy += p.accuracy;
    }
    
    final count = windowPoints.length;
    
    return WalkPoint(
      latitude: sumLat / count,
      longitude: sumLon / count,
      altitude: sumAlt / count,
      speed: sumSpeed / count,
      accuracy: sumAccuracy / count,
      timestamp: point.timestamp,
    );
  }

  /// Добавить точку в буфер с ограничением размера
  void _addToBuffer(List<WalkPoint> buffer, WalkPoint point, int maxSize) {
    buffer.add(point);
    while (buffer.length > maxSize) {
      buffer.removeAt(0);
    }
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
    _pendingPoints.clear();
    _pointsReceived = 0;
    _pointsAccepted = 0;
    _trackingStartTime = null;
    print('Отслеживание GPS остановлено');
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
