import 'dart:async';
import 'dart:math' as math;
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../config/app_config.dart';

/// Буфер для хранения последних N значений с возможностью получения статистики
class _CircularBuffer {
  final List<double> _buffer = [];
  final int maxSize;
  
  _CircularBuffer(this.maxSize);
  
  void add(double value) {
    _buffer.add(value);
    if (_buffer.length > maxSize) {
      _buffer.removeAt(0);
    }
  }
  
  List<double> get values => List.unmodifiable(_buffer);
  
  double get max => _buffer.reduce((a, b) => a > b ? a : b);
  double get min => _buffer.reduce((a, b) => a < b ? a : b);
  
  double get last => _buffer.last;
  double? get preLast => _buffer.length >= 2 ? _buffer[_buffer.length - 2] : null;
  
  bool get isMaxVal {
    if (_buffer.isEmpty) return false;
    final lastVal = _buffer.last;
    for (final val in _buffer) {
      if (val > lastVal) return false;
    }
    return true;
  }
  
  double get avg {
    if (_buffer.isEmpty) return 0;
    final sum = _buffer.reduce((a, b) => a + b);
    return sum / _buffer.length;
  }
  
  void clear() => _buffer.clear();
  
  int get length => _buffer.length;
  bool get isEmpty => _buffer.isEmpty;
  bool get isNotEmpty => _buffer.isNotEmpty;
}

/// Сервис для подсчёта шагов с адаптивной чувствительностью
/// Реализация основана на алгоритме, проверенном на устройствах с датчиком ускорения
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
  
  // Параметры для расчёта расстояния
  double _averageStepLength = 0.75; // метров
  
  // ========== Параметры алгоритма детекции шагов (из проверенного Java-кода) ==========
  
  // Фильтр сглаживания (convBuffer в Java)
  final _CircularBuffer _convBuffer = _CircularBuffer(5);
  
  // Буферы для поиска пиков (accBuffer, timeBuffer в Java)
  final _CircularBuffer _accBuffer = _CircularBuffer(20);
  final _CircularBuffer _timeBuffer = _CircularBuffer(20);
  
  // Время предыдущего шага (для проверки интервала)
  double _stepTimePred = 0;
  
  // Флаг что идёт серия шагов
  bool _isStepSeries = false;
  
  // Время начала для нормализации
  double _startTime = 0;
  bool _isJustStarted = true;
  
  // Счётчик детектированных шагов
  int _detectedSteps = 0;
  
  // Настройки чувствительности (можно менять)
  double _sensitivity = 1.0; // 0.5 - 2.0, влияет на мин. амплитуду
  
  // Мин/макс интервал между шагами в секундах
  double _minStepInterval = 0.4; // сек
  double _maxStepInterval = 1.8; // сек
  
  // ========== Конец параметров алгоритма ==========

  /// Текущее количество шагов
  int get currentSteps => _currentSteps;

  /// Активен ли подсчёт
  bool get isCounting => _isCounting;
  
  /// Текущая чувствительность
  double get sensitivity => _sensitivity;
  
  /// Средняя длина шага
  double get averageStepLength => _averageStepLength;

  /// Установить параметры чувствительности
  /// value: 0.5 - минимум (для слабых шагов), 2.0 - максимум (для сильных шагов)
  void setSensitivity(double value) {
    _sensitivity = value.clamp(0.5, 2.0);
    // Чем выше чувствительность, тем короче может быть интервал
    _minStepInterval = 0.4 / _sensitivity;
    if (AppConfig.enableLogging) {
      print('Pedometer: чувствительность=$_sensitivity, мин.интервал=${_minStepInterval.toStringAsFixed(2)} сек');
    }
  }
  
  /// Установить среднюю длину шага
  void setAverageStepLength(double meters) {
    _averageStepLength = meters.clamp(0.5, 1.0);
    if (AppConfig.enableLogging) {
      print('Pedometer: средняя длина шага=$_averageStepLength м');
    }
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
            print('Pedometer: ошибка системного шагомера: $error, переключаемся на акселерометр');
          }
          _startAccelerometerCounting();
        },
      );
    } catch (e) {
      if (AppConfig.enableLogging) {
        print('Pedometer: ошибка запуска шагомера: $e, переключаемся на акселерометр');
      }
      await _startAccelerometerCounting();
    }
  }

  /// Запуск подсчёта через акселерометр
  /// Алгоритм основан на проверенном Java-коде для устройств с датчиком ускорения
  Future<void> _startAccelerometerCounting() async {
    _isCounting = true;
    _detectedSteps = 0;
    _currentSteps = 0;
    _isJustStarted = true;
    _stepTimePred = 0;
    _isStepSeries = false;
    _convBuffer.clear();
    _accBuffer.clear();
    _timeBuffer.clear();

    if (AppConfig.enableLogging) {
      print('Pedometer: запуск подсчёта через акселерометр (алгоритм на основе пиков)');
    }

    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _processAccelerometerData(event);
    });
  }
  
  /// Обработка данных акселерометра (основной алгоритм из Java-кода)
  void _processAccelerometerData(AccelerometerEvent event) {
    // Получаем время в секундах
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    
    // Инициализация времени старта
    if (_isJustStarted) {
      _startTime = time;
      _isJustStarted = false;
    }
    final normalizedTime = time - _startTime;
    
    // === Шаг 1: Находим лучшую ось (максимум из трёх) ===
    // Это ключевое отличие от вычисления магнитуды!
    final xy = event.x.abs();
    final xz = event.y.abs();
    final zy = event.z.abs();
    double acc = math.max(math.max(xy, xz), zy);
    
    // === Шаг 2: Сглаживание через свёртку (скользящее среднее) ===
    _convBuffer.add(acc);
    acc = _convBuffer.avg;
    
    // === Шаг 3: Добавляем в буферы ===
    _accBuffer.add(acc);
    _timeBuffer.add(normalizedTime);
    
    // Ждём заполнения буфера
    if (_accBuffer.length < 10) return;
    
    // === Шаг 4: Находим min/max и адаптивный порог ===
    final accBufMax = _accBuffer.max;
    final accBufMin = _accBuffer.min;
    final amplitude = accBufMax - accBufMin;
    
    // Проверка минимальной амплитуды (подстройка чувствительности)
    // Чем выше sensitivity, тем меньшую амплитуду пропускаем
    final minAmplitude = 1.0 / _sensitivity;
    if (amplitude < minAmplitude) {
      return; // Слишком мало движения
    }
    
    // Адаптивный порог = среднее между min и max
    final levelFindSteps = (accBufMax + accBufMin) / 2;
    
    // === Шаг 5: Поиск локального максимума ===
    if (_accBuffer.isMaxVal && 
        _accBuffer.preLast != null && 
        _accBuffer.preLast! > levelFindSteps) {
      
      // Время кандидата на шаг (предпоследний элемент)
      final stepTimeCandidate = _timeBuffer.preLast ?? normalizedTime;
      final dt = stepTimeCandidate - _stepTimePred;
      
      // === Шаг 6: Проверка временного интервала ===
      
      // Если прошлый шаг был давно, начинаем новую серию
      if (stepTimeCandidate - _stepTimePred > 2.0) {
        _stepTimePred = stepTimeCandidate;
        _isStepSeries = false;
        if (AppConfig.enableLogging) {
          print('Pedometer: новая серия шагов началась');
        }
      }
      
      // Проверяем интервал между шагами (0.4 - 1.8 сек, с учётом чувствительности)
      final minInterval = _minStepInterval;
      final maxInterval = _maxStepInterval;
      
      if (dt > minInterval && dt <= maxInterval) {
        // Если уже идёт серия шагов - засчитываем шаг
        if (_isStepSeries) {
          _detectedSteps++;
          _currentSteps = _detectedSteps;
          _stepsController.add(_currentSteps);
          
          final distance = _currentSteps * _averageStepLength;
          _distanceController.add(distance);
          
          if (AppConfig.enableLogging) {
            print('Pedometer: ШАГ #$_detectedSteps, dt=${dt.toStringAsFixed(2)} сек, амплитуда=${amplitude.toStringAsFixed(2)}');
          }
        }
        _isStepSeries = true;
        _stepTimePred = stepTimeCandidate;
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
    _isJustStarted = true;
    _stepTimePred = 0;
    _isStepSeries = false;
    _convBuffer.clear();
    _accBuffer.clear();
    _timeBuffer.clear();
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
