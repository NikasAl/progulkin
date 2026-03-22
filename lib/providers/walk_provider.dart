import 'package:flutter/foundation.dart';
import '../models/walk.dart';
import '../models/walk_point.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';

/// Провайдер для управления прогулками
class WalkProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();

  Walk? _currentWalk;
  List<Walk> _walksHistory = [];
  bool _isTracking = false;
  bool _isLoading = false;
  String? _error;

  // Геттеры
  Walk? get currentWalk => _currentWalk;
  List<Walk> get walksHistory => _walksHistory;
  bool get isTracking => _isTracking;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveWalk => _currentWalk != null && _currentWalk!.isActive;

  /// Инициализация
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.init();
      _walksHistory = await _storageService.getAllWalks();
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки данных: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Начать новую прогулку
  Future<bool> startWalk() async {
    try {
      // Проверяем разрешения
      final hasPermission = await _locationService.checkPermission();
      if (!hasPermission) {
        _error = 'Нет разрешения на геолокацию';
        notifyListeners();
        return false;
      }

      // Создаём новую прогулку
      _currentWalk = Walk(startTime: DateTime.now());
      _isTracking = true;

      // Получаем начальную позицию
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _currentWalk!.points.add(position);
      }

      // Начинаем отслеживание
      _locationService.positionStream.listen((point) {
        if (_isTracking && _currentWalk != null) {
          _currentWalk!.points.add(point);
          notifyListeners();
        }
      });

      await _locationService.startTracking();

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка начала прогулки: $e';
      notifyListeners();
      return false;
    }
  }

  /// Остановить прогулку
  Future<bool> stopWalk({int steps = 0}) async {
    try {
      if (_currentWalk == null) return false;

      _isTracking = false;
      _locationService.stopTracking();

      _currentWalk!.endTime = DateTime.now();
      _currentWalk!.steps = steps;

      // Сохраняем прогулку
      await _storageService.saveWalk(_currentWalk!);

      // Добавляем в историю
      _walksHistory.insert(0, _currentWalk!);
      _currentWalk = null;

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка остановки прогулки: $e';
      notifyListeners();
      return false;
    }
  }

  /// Приостановить прогулку
  void pauseWalk() {
    if (_isTracking) {
      _locationService.stopTracking();
      _isTracking = false;
      notifyListeners();
    }
  }

  /// Продолжить прогулку
  Future<void> resumeWalk() async {
    if (_currentWalk != null && !_isTracking) {
      await _locationService.startTracking();
      _isTracking = true;
      notifyListeners();
    }
  }

  /// Отменить текущую прогулку
  void cancelWalk() {
    _locationService.stopTracking();
    _currentWalk = null;
    _isTracking = false;
    notifyListeners();
  }

  /// Обновить шаги в текущей прогулке
  void updateSteps(int steps) {
    if (_currentWalk != null) {
      _currentWalk!.steps = steps;
      notifyListeners();
    }
  }

  /// Удалить прогулку из истории
  Future<bool> deleteWalk(String walkId) async {
    try {
      await _storageService.deleteWalk(walkId);
      _walksHistory.removeWhere((w) => w.id == walkId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка удаления прогулки: $e';
      notifyListeners();
      return false;
    }
  }

  /// Получить прогулку по ID
  Walk? getWalkById(String id) {
    try {
      return _walksHistory.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Получить статистику
  Future<Map<String, dynamic>> getStatistics() async {
    return _storageService.getStatistics();
  }

  /// Очистить ошибку
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}
