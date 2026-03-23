import 'dart:async';
import 'dart:math' as math;
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../config/app_config.dart';

/// Сервис для подсчёта шагов с адаптивной чувствительностью
class PedometerService {
  static final PedometerService _instance = PedometerService._internal();
  factory PedometerService() => _instance;
  PedometerService._internal();

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  
  final StreamController<int> _stepsController = StreamController<int>.broadcast();
  final StreamController<double> _distanceController = StreamController<double>.broadcast();
  
  /// Поток шагов для подписки
  Stream<int> get stepsStream => _stepsController.stream;
  
  /// Поток расстояния для подписки
  Stream<double> get distanceStream => _distanceController.stream;

  int _currentSteps = 0;
  int _initialSteps = 0;
  bool _isCounting = false;
  
  // Адаптивные параметры для детекции шагов
  double _sensitivity = 1.0; // Коэффициент чувствительности (0.5 - 2.0)
  double _baseThreshold = 25.0; // Базовый порог
  int _minStepIntervalMs = 250;
  double _averageStepLength = 0.75; // метров
  
  // Для адаптивной калибровки
  final List<double> _recentMagnitudes = [];
  double _dynamicThreshold = 25.0;
  int _calibrationSteps = 0;
  
  // Для детекции шагов
  double _lastAccelMagnitude = 0;
  int _lastStepTime = 0;
  int _detectedSteps = 0;
  
  // Для фильтрации шума
  final List<double> _magnitudeBuffer = [];
  static const int _bufferSize = 5;

  /// Текущее количество шагов
  int get currentSteps => _currentSteps;

  /// Активен ли подсчёт
  bool get isCounting => _isCounting;
  
  /// Текущая чувствительность
  double get sensitivity => _sensitivity;
  
  /// Средняя длина шага
  double get averageStepLength => _averageStepLength;

  /// Установить параметры чувствительности
  void setSensitivity(double value) {
    _sensitivity = value.clamp(0.5, 2.0);
    _updateDynamicThreshold();
    print('Чувствительность: $_sensitivity, порог: $_dynamicThreshold');
  }
  
  /// Установить среднюю длину шага
  void setAverageStepLength(double meters) {
    _averageStepLength = meters.clamp(0.5, 1.0);
    print('Средняя длина шага: $_averageStepLength м');
  }
  
  /// Установить минимальный интервал между шагами
  void setMinStepInterval(int ms) {
    _minStepIntervalMs = ms.clamp(150, 500);
  }
  
  /// Обновить динамический порог на основе чувствительности
  void _updateDynamicThreshold() {
    _dynamicThreshold = _baseThreshold / _sensitivity;
  }

  /// Проверка разрешений
  Future<bool> checkPermission() async {
    final activityStatus = await Permission.activityRecognition.status;
    if (activityStatus.isDenied) {
      final result = await Permission.activityRecognition.request();
      if (result.isDenied || result.isPermanentlyDenied) {
        return false;
      }
    }
    return true;
  }

  /// Начать подсчёт шагов
  Future<void> startCounting() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      await _startAccelerometerCounting();
      return;
    }

    _isCounting = true;
    _initialSteps = 0;
    _currentSteps = 0;

    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        (StepCount stepCount) {
          if (_initialSteps == 0) {
            _initialSteps = stepCount.steps;
          }
          _currentSteps = stepCount.steps - _initialSteps;
          _stepsController.add(_currentSteps);
          
          final distance = _currentSteps * _averageStepLength;
          _distanceController.add(distance);
        },
        onError: (error) {
          if (AppConfig.enableLogging) {
            print('Ошибка шагомера: $error');
          }
          _startAccelerometerCounting();
        },
      );
    } catch (e) {
      if (AppConfig.enableLogging) {
        print('Ошибка запуска шагомера: $e');
      }
      await _startAccelerometerCounting();
    }
  }

  /// Запуск подсчёта через акселерометр с адаптивной чувствительностью
  Future<void> _startAccelerometerCounting() async {
    _isCounting = true;
    _detectedSteps = 0;
    _currentSteps = 0;
    _recentMagnitudes.clear();
    _magnitudeBuffer.clear();
    _calibrationSteps = 0;
    _updateDynamicThreshold();

    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Вычисляем магнитуду ускорения (без гравитации ~9.8)
      final magnitude = _calculateMagnitude(event.x, event.y, event.z);
      
      // Сглаживание сигнала (скользящее среднее)
      _magnitudeBuffer.add(magnitude);
      if (_magnitudeBuffer.length > _bufferSize) {
        _magnitudeBuffer.removeAt(0);
      }
      final smoothedMagnitude = _magnitudeBuffer.isEmpty 
          ? magnitude 
          : _magnitudeBuffer.reduce((a, b) => a + b) / _magnitudeBuffer.length;
      
      // Адаптивная калибровка порога
      _adaptThreshold(smoothedMagnitude);
      
      // Детекция шага по пику ускорения
      if (smoothedMagnitude > _dynamicThreshold && 
          _lastAccelMagnitude <= _dynamicThreshold &&
          (now - _lastStepTime) > _minStepIntervalMs) {
        
        _detectedSteps++;
        _currentSteps = _detectedSteps;
        _stepsController.add(_currentSteps);
        
        final distance = _currentSteps * _averageStepLength;
        _distanceController.add(distance);
        
        _lastStepTime = now;
        
        // Сохраняем магнитуду для адаптации
        _recentMagnitudes.add(smoothedMagnitude);
        if (_recentMagnitudes.length > 20) {
          _recentMagnitudes.removeAt(0);
        }
      }
      
      _lastAccelMagnitude = smoothedMagnitude;
    });
  }
  
  /// Вычисление магнитуды ускорения
  double _calculateMagnitude(double x, double y, double z) {
    // Вычитаем гравитацию (~9.8 м/с²) и берём абсолютное значение
    final gravity = 9.8;
    final totalAccel = math.sqrt(x * x + y * y + z * z);
    return (totalAccel - gravity).abs();
  }
  
  /// Адаптивная калибровка порога
  void _adaptThreshold(double currentMagnitude) {
    _calibrationSteps++;
    
    // Каждые 50 измерений обновляем порог
    if (_calibrationSteps % 50 == 0 && _recentMagnitudes.isNotEmpty) {
      // Вычисляем среднее и стандартное отклонение
      final avg = _recentMagnitudes.reduce((a, b) => a + b) / _recentMagnitudes.length;
      
      // Адаптируем порог на основе средней активности
      if (avg > 0) {
        // Порог = среднее * 0.7, но не меньше базового / 2
        final adaptedThreshold = math.max(avg * 0.7, _baseThreshold / _sensitivity / 2);
        _dynamicThreshold = adaptedThreshold;
      }
    }
  }

  /// Остановить подсчёт
  void stopCounting() {
    _stepCountSubscription?.cancel();
    _stepCountSubscription = null;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isCounting = false;
  }

  /// Сбросить счётчик
  void reset() {
    _currentSteps = 0;
    _initialSteps = 0;
    _detectedSteps = 0;
    _recentMagnitudes.clear();
    _magnitudeBuffer.clear();
    _calibrationSteps = 0;
    _stepsController.add(0);
  }

  /// Установить начальное значение шагов
  void setInitialSteps(int steps) {
    _initialSteps = steps;
  }

  /// Освобождение ресурсов
  void dispose() {
    stopCounting();
    _stepsController.close();
    _distanceController.close();
  }
}
