import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../config/app_config.dart';

/// Сервис для подсчёта шагов
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
  
  // Параметры для детекции шагов через акселерометр
  double _lastAccelMagnitude = 0;
  int _lastStepTime = 0;
  int _detectedSteps = 0;

  /// Текущее количество шагов
  int get currentSteps => _currentSteps;

  /// Активен ли подсчёт
  bool get isCounting => _isCounting;

  /// Проверка разрешений
  Future<bool> checkPermission() async {
    // Проверяем разрешение на активность (для iOS)
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
      // Если нет разрешения, используем акселерометр
      await _startAccelerometerCounting();
      return;
    }

    _isCounting = true;
    _initialSteps = 0;
    _currentSteps = 0;

    try {
      // Используем нативный шагомер
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        (StepCount stepCount) {
          if (_initialSteps == 0) {
            _initialSteps = stepCount.steps;
          }
          _currentSteps = stepCount.steps - _initialSteps;
          _stepsController.add(_currentSteps);
          
          // Расчёт расстояния на основе средней длины шага из конфига
          final distance = _currentSteps * AppConfig.averageStepLength;
          _distanceController.add(distance);
        },
        onError: (error) {
          if (AppConfig.enableLogging) {
            print('Ошибка шагомера: $error');
          }
          // Fallback на акселерометр
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

  /// Запуск подсчёта через акселерометр (fallback)
  Future<void> _startAccelerometerCounting() async {
    _isCounting = true;
    _detectedSteps = 0;
    _currentSteps = 0;

    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Вычисляем магнитуду ускорения
      final magnitude = (event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Детекция шага по пику ускорения с параметрами из конфига
      if (magnitude > AppConfig.stepDetectionThreshold && 
          _lastAccelMagnitude <= AppConfig.stepDetectionThreshold &&
          (now - _lastStepTime) > AppConfig.minStepIntervalMs) {
        _detectedSteps++;
        _currentSteps = _detectedSteps;
        _stepsController.add(_currentSteps);
        
        final distance = _currentSteps * AppConfig.averageStepLength;
        _distanceController.add(distance);
        
        _lastStepTime = now;
      }
      
      _lastAccelMagnitude = magnitude;
    });
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
