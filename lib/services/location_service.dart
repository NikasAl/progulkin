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
  final List<WalkPoint> _recentPoints = []; // Для медианного фильтра и фильтрации
  int _pointsReceived = 0;
  int _pointsAccepted = 0;

  // Настройки фильтрации (настраиваемые)
  double maxWalkingSpeedKmh = 10.0; // км/ч - макс. скорость ходьбы
  double maxAccuracyMeters = 50.0; // макс. допустимая погрешность
  bool enableSmoothing = false; // сглаживание отключено по умолчанию для лучшей точности
  int smoothingWindowSize = 3; // окно для сглаживания

  // Настройки адаптивного сглаживания
  double sharpTurnThresholdDegrees = 30.0; // угол для определения резкого поворота
  double smoothingWeight = 0.5; // вес текущей точки (0.5 = 50% вес, 0.33 = равные веса для 3 точек)
  bool enableAdaptiveSmoothing = true; // адаптивное сглаживание с сохранением поворотов
  
  // Настройки определения неподвижности
  double stationaryRadiusMeters = 10.0; // радиус для определения неподвижности
  int stationaryMinPoints = 15; // количество точек для проверки (15 точек = 30 сек)
  bool enableStationaryDetection = true; // включить определение неподвижности

  // Переменные для определения неподвижности
  bool _isStationary = false;
  WalkPoint? _stationaryStartPoint; // первая точка группы для проверки
  List<WalkPoint> _stationaryBuffer = []; // буфер точек кандидатов

  /// Обновить настройки фильтрации
  void updateSettings({
    double? maxSpeed,
    double? maxAccuracy,
    bool? smoothing,
    double? stationaryRadius,
    bool? stationaryDetection,
    bool? adaptiveSmoothing,
    double? turnThreshold,
    double? smoothingWeight,
  }) {
    if (maxSpeed != null) maxWalkingSpeedKmh = maxSpeed;
    if (maxAccuracy != null) maxAccuracyMeters = maxAccuracy;
    if (smoothing != null) enableSmoothing = smoothing;
    if (stationaryRadius != null) stationaryRadiusMeters = stationaryRadius;
    if (stationaryDetection != null) enableStationaryDetection = stationaryDetection;
    if (adaptiveSmoothing != null) enableAdaptiveSmoothing = adaptiveSmoothing;
    if (turnThreshold != null) sharpTurnThresholdDegrees = turnThreshold;
    if (smoothingWeight != null) this.smoothingWeight = smoothingWeight;
    print('Настройки: скорость=$maxWalkingSpeedKmh км/ч, точность=$maxAccuracyMeters м, радиус неподвижности=$stationaryRadiusMeters м');
    print('Сглаживание: вкл=$enableSmoothing, адаптивное=$enableAdaptiveSmoothing, порог поворота=$sharpTurnThresholdDegrees°, вес=${this.smoothingWeight}');
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
    _stationaryBuffer.clear();
    _stationaryStartPoint = null;
    _pointsReceived = 0;
    _pointsAccepted = 0;
    _isStationary = false;

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

    // Определение неподвижности
    if (enableStationaryDetection) {
      _checkStationary(walkPoint);
      if (_isStationary) {
        if (AppConfig.enableLogging) {
          print('⊙ Неподвижность: точка в радиусе ${stationaryRadiusMeters.toStringAsFixed(0)}м');
        }
        // Не добавляем точку, но обновляем последнюю валидную
        return;
      }
    }

    // Многоуровневая фильтрация
    final filterResult = _applyFilters(walkPoint);
    
    if (filterResult.accepted && filterResult.point != null) {
      _pointsAccepted++;
      
      // Вычисляем heading из последних двух точек
      WalkPoint finalPoint = filterResult.point!;
      if (_lastValidPoint != null) {
        final heading = calculateBearing(_lastValidPoint!, finalPoint);
        finalPoint = finalPoint.copyWith(heading: heading);
      }
      
      _lastValidPoint = finalPoint;
      
      // Добавляем в буфер
      _recentPoints.add(finalPoint);
      if (_recentPoints.length > 10) {
        _recentPoints.removeAt(0);
      }
      
      _positionController.add(finalPoint);
      
      if (AppConfig.enableLogging) {
        print('✓ ПРИНЯТА (принято: $_pointsAccepted из $_pointsReceived), heading: ${finalPoint.heading.toStringAsFixed(0)}°');
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

    // 7. Адаптивное сглаживание с сохранением поворотов
    WalkPoint finalPoint = point;

    if (enableSmoothing && _recentPoints.length >= smoothingWindowSize) {
      final shouldSmooth = _shouldSmoothPoint(point);

      if (shouldSmooth) {
        finalPoint = _applyWeightedSmoothing(point);

        if (AppConfig.enableLogging) {
          final smoothed = finalPoint;
          final origLat = point.latitude;
          final origLon = point.longitude;
          final smoothLat = smoothed.latitude;
          final smoothLon = smoothed.longitude;
          final shift = _calculateDistance(origLat, origLon, smoothLat, smoothLon);
          print('〰️ Сглаживание: смещение ${shift.toStringAsFixed(2)}м');
        }
      } else {
        if (AppConfig.enableLogging) {
          print('🔺 Поворот сохранён без сглаживания');
        }
      }
    }

    return _FilterResult(accepted: true, point: finalPoint);
  }

  /// Проверка, нужно ли сглаживать точку (обнаружение поворотов)
  bool _shouldSmoothPoint(WalkPoint point) {
    if (!enableAdaptiveSmoothing) {
      return true; // Старое поведение - всегда сглаживать
    }

    // Нужно минимум 2 предыдущие точки для определения угла
    if (_recentPoints.length < 2) {
      return true;
    }

    final prevPoint = _recentPoints[_recentPoints.length - 1];
    final prevPrevPoint = _recentPoints[_recentPoints.length - 2];

    // Вычисляем векторы направления
    final bearing1 = calculateBearing(prevPrevPoint, prevPoint);
    final bearing2 = calculateBearing(prevPoint, point);

    // Вычисляем изменение направления
    double angleChange = (bearing2 - bearing1).abs();
    if (angleChange > 180) {
      angleChange = 360 - angleChange;
    }

    // Если изменение направления больше порога - это поворот, не сглаживаем
    if (angleChange > sharpTurnThresholdDegrees) {
      if (AppConfig.enableLogging) {
        print('↪️ Обнаружен поворот: ${angleChange.toStringAsFixed(1)}°');
      }
      return false;
    }

    return true;
  }

  /// Вычисление азимута (направления) между двумя точками
  double calculateBearing(WalkPoint from, WalkPoint to) {
    final double lat1 = _toRadians(from.latitude);
    final double lat2 = _toRadians(to.latitude);
    final double dLon = _toRadians(to.longitude - from.longitude);

    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Взвешенное сглаживание с приоритетом текущей точки
  WalkPoint _applyWeightedSmoothing(WalkPoint point) {
    final windowPoints = _recentPoints.sublist(
      _recentPoints.length - smoothingWindowSize + 1
    )..add(point);

    // Взвешенное среднее с бо́льшим весом для текущей точки
    double sumLat = 0, sumLon = 0, totalWeight = 0;

    for (int i = 0; i < windowPoints.length; i++) {
      double weight;

      if (enableAdaptiveSmoothing) {
        // Взвешенное окно: текущая точка имеет бо́льший вес
        if (i == windowPoints.length - 1) {
          // Текущая точка
          weight = smoothingWeight;
        } else {
          // Остальные точки делят оставшийся вес поровну
          weight = (1.0 - smoothingWeight) / (windowPoints.length - 1);
        }
      } else {
        // Старое поведение - равные веса
        weight = 1.0 / windowPoints.length;
      }

      sumLat += windowPoints[i].latitude * weight;
      sumLon += windowPoints[i].longitude * weight;
      totalWeight += weight;
    }

    return WalkPoint(
      latitude: sumLat / totalWeight,
      longitude: sumLon / totalWeight,
      altitude: point.altitude,
      speed: point.speed,
      accuracy: point.accuracy,
      timestamp: point.timestamp,
    );
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

  /// Проверка неподвижности - новый алгоритм
  /// Отслеживаем смещение от начальной точки за длительный период
  /// Если за 30+ секунд смещение меньше радиуса - человек стоит
  void _checkStationary(WalkPoint newPoint) {
    // Если нет начальной точки, запоминаем текущую как кандидат
    if (_stationaryStartPoint == null) {
      _stationaryStartPoint = newPoint;
      _stationaryBuffer = [newPoint];
      _isStationary = false;
      if (AppConfig.enableLogging) {
        print('📍 Новая точка отсчёта для проверки неподвижности');
      }
      return;
    }
    
    // Проверяем расстояние от начальной точки
    final distanceFromStart = _calculateDistance(
      _stationaryStartPoint!.latitude, 
      _stationaryStartPoint!.longitude,
      newPoint.latitude, 
      newPoint.longitude,
    );
    
    if (AppConfig.enableLogging) {
      print('📏 Расстояние от начала: ${distanceFromStart.toStringAsFixed(1)}м, буфер: ${_stationaryBuffer.length}');
    }
    
    // Если превысили радиус - движение! Сбрасываем и начинаем сначала
    if (distanceFromStart > stationaryRadiusMeters) {
      if (_isStationary) {
        if (AppConfig.enableLogging) {
          print('⚡ Вышли из неподвижности (прошли ${distanceFromStart.toStringAsFixed(1)}м)');
        }
      }
      _stationaryStartPoint = newPoint;
      _stationaryBuffer = [newPoint];
      _isStationary = false;
      return;
    }
    
    // Точка в пределах радиуса - добавляем в буфер
    _stationaryBuffer.add(newPoint);
    
    // Проверяем, достаточно ли точек для вывода о неподвижности
    if (_stationaryBuffer.length >= stationaryMinPoints) {
      // Вычисляем время в неподвижности
      final duration = _stationaryBuffer.last.timestamp
          .difference(_stationaryBuffer.first.timestamp).inSeconds;
      
      if (!_isStationary) {
        if (AppConfig.enableLogging) {
          print('⚠ Неподвижность подтверждена ($duration сек, ${_stationaryBuffer.length} точек)');
        }
        _isStationary = true;
      }
    } else {
      // Ещё собираем данные, но пока считаем движением
      _isStationary = false;
    }
  }

  /// Проверка, неподвижен ли пользователь
  bool get isStationary => _isStationary;

  /// Остановить отслеживание
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _lastValidPoint = null;
    _recentPoints.clear();
    _stationaryBuffer.clear();
    _stationaryStartPoint = null;
    _pointsReceived = 0;
    _pointsAccepted = 0;
    _isStationary = false;
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
      timestamp: position.timestamp,
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
