import 'package:flutter/foundation.dart';
import '../services/pedometer_service.dart';

/// Провайдер для управления подсчётом шагов
class PedometerProvider extends ChangeNotifier {
  final PedometerService _pedometerService = PedometerService();

  int _steps = 0;
  double _distance = 0;
  bool _isCounting = false;
  String? _error;

  // Геттеры
  int get steps => _steps;
  double get distance => _distance;
  bool get isCounting => _isCounting;
  String? get error => _error;

  /// Форматированное расстояние
  String get formattedDistance {
    if (_distance >= 1000) {
      return '${(_distance / 1000).toStringAsFixed(2)} км';
    }
    return '${_distance.toStringAsFixed(0)} м';
  }

  /// Инициализация
  Future<void> init() async {
    // Проверяем доступность
    final hasPermission = await _pedometerService.checkPermission();
    if (!hasPermission) {
      _error = 'Нет разрешения на использование датчиков';
      notifyListeners();
    }
  }

  /// Начать подсчёт
  Future<void> startCounting() async {
    try {
      await _pedometerService.startCounting();
      _isCounting = true;

      // Подписываемся на обновления - объединяем для избежания двойного notifyListeners
      int pendingUpdates = 0;
      
      _pedometerService.stepsStream.listen((steps) {
        _steps = steps;
        pendingUpdates++;
        if (pendingUpdates >= 2) {
          notifyListeners();
          pendingUpdates = 0;
        }
      });

      _pedometerService.distanceStream.listen((distance) {
        _distance = distance;
        pendingUpdates++;
        if (pendingUpdates >= 2) {
          notifyListeners();
          pendingUpdates = 0;
        }
      });

      notifyListeners();
    } catch (e) {
      _error = 'Ошибка запуска шагомера: $e';
      notifyListeners();
    }
  }

  /// Приостановить подсчёт (без сброса счётчика)
  void pauseCounting() {
    _pedometerService.pauseCounting();
    _isCounting = false;
    notifyListeners();
  }

  /// Продолжить подсчёт (без сброса счётчика)
  Future<void> resumeCounting() async {
    try {
      await _pedometerService.resumeCounting();
      _isCounting = true;
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка возобновления шагомера: $e';
      notifyListeners();
    }
  }

  /// Остановить подсчёт
  void stopCounting() {
    _pedometerService.stopCounting();
    _isCounting = false;
    notifyListeners();
  }

  /// Получить текущее количество шагов (для сохранения при завершении прогулки)
  int getCurrentSteps() {
    return _steps;
  }

  /// Сбросить счётчик
  void reset() {
    _pedometerService.reset();
    _steps = 0;
    _distance = 0;
    notifyListeners();
  }

  /// Очистить ошибку
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pedometerService.dispose();
    super.dispose();
  }
}
