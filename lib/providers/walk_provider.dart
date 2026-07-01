import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/walk.dart';
import '../models/walk_point.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../services/pedometer_service.dart';

/// Провайдер для управления прогулками
class WalkProvider extends ChangeNotifier {
  final LocationService _locationService;
  final StorageService _storageService;
  final PedometerService _pedometerService;

  /// Конструктор с инъекцией зависимостей
  WalkProvider({
    required LocationService locationService,
    required StorageService storageService,
    required PedometerService pedometerService,
  })  : _locationService = locationService,
        _storageService = storageService,
        _pedometerService = pedometerService;

  Walk? _currentWalk;
  
  /// Список метаданных прогулок (без точек - для быстрого отображения)
  List<WalkMetadata> _walksHistory = [];
  
  /// Кэш полных прогулок (с точками) - загружается по требованию
  final Map<String, Walk> _walksCache = {};
  
  bool _isTracking = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  StreamSubscription<WalkPoint>? _positionSubscription;
  
  /// Пагинация
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMore = true;
  int _totalCount = 0;
  
  // Время паузы для корректного отображения duration
  DateTime? _pauseStartTime;
  Duration _totalPauseDuration = Duration.zero; // Сумма всех периодов паузы

  // Настройки источника расстояния
  DistanceSource _distanceSource = DistanceSource.pedometer;
  double _stepLength = 0.75;

  // Геттеры
  Walk? get currentWalk => _currentWalk;
  List<WalkMetadata> get walksHistory => _walksHistory;
  bool get isTracking => _isTracking;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;
  String? get error => _error;
  bool get hasActiveWalk => _currentWalk != null && _currentWalk!.isActive;
  DistanceSource get distanceSource => _distanceSource;
  double get stepLength => _stepLength;
  
  /// Прогулка существует, но на паузе
  bool get isPaused => _currentWalk != null && !_isTracking;
  
  /// Есть текущая прогулка (активная или на паузе)
  bool get hasCurrentWalk => _currentWalk != null;
  
  /// Продолжительность текущей прогулки (с учётом паузы)
  Duration get currentWalkDuration {
    if (_currentWalk == null) return Duration.zero;
    
    final elapsed = DateTime.now().difference(_currentWalk!.startTime);
    
    if (_isTracking) {
      // Активная прогулка - вычитаем всё время пауз
      return elapsed - _totalPauseDuration;
    } else {
      // На паузе - вычитаем также текущую паузу
      final currentPause = _pauseStartTime != null 
          ? DateTime.now().difference(_pauseStartTime!) 
          : Duration.zero;
      return elapsed - _totalPauseDuration - currentPause;
    }
  }
  
  /// Форматированная продолжительность текущей прогулки
  String get currentWalkFormattedDuration {
    final d = currentWalkDuration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hoursч $minutesмин';
    } else if (minutes > 0) {
      return '$minutesмин $secondsсек';
    }
    return '$secondsсек';
  }

  /// Инициализация - загружает только первую страницу метаданных (быстро)
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.init();
      
      // Загружаем только первую страницу (быстро, без точек)
      _currentPage = 0;
      _hasMore = true;
      _walksHistory = await _storageService.getWalksMetadataPaginated(
        limit: _pageSize,
        offset: 0,
      );
      _totalCount = await _storageService.getWalksCount();
      _hasMore = _walksHistory.length < _totalCount;
      
      // Загружаем настройки
      await _loadSettings();
      
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки данных: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Загрузить следующую страницу прогулок (пагинация)
  Future<void> loadMoreWalks() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextOffset = (_currentPage + 1) * _pageSize;
      final moreWalks = await _storageService.getWalksMetadataPaginated(
        limit: _pageSize,
        offset: nextOffset,
      );

      if (moreWalks.isNotEmpty) {
        _walksHistory.addAll(moreWalks);
        _currentPage++;
      }
      _hasMore = moreWalks.length == _pageSize;
    } catch (e) {
      _error = 'Ошибка загрузки прогулок: $e';
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Получить полный Walk (с точками) по ID - с кэшированием
  Future<Walk?> getWalkDetails(String id) async {
    // Проверяем кэш
    if (_walksCache.containsKey(id)) {
      return _walksCache[id];
    }

    try {
      final walk = await _storageService.getWalkById(id);
      if (walk != null) {
        _walksCache[id] = walk;
        // Ограничиваем размер кэша
        if (_walksCache.length > 5) {
          _walksCache.remove(_walksCache.keys.first);
        }
      }
      return walk;
    } catch (e) {
      debugPrint('Ошибка загрузки деталей прогулки $id: $e');
      return null;
    }
  }

  /// Получить метаданные прогулки по ID (быстро, из памяти)
  WalkMetadata? getWalkMetadataById(String id) {
    try {
      return _walksHistory.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
  
  /// Загрузка настроек
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final sourceIndex = prefs.getInt('distanceSource') ?? 1; // Default: pedometer
    _distanceSource = DistanceSource.values[sourceIndex.clamp(0, 2)];
    _stepLength = prefs.getDouble('stepLength') ?? 0.75;
    
    // Применяем к педометру
    _pedometerService.setAverageStepLength(_stepLength);
  }
  
  /// Сохранение настроек
  Future<void> saveSettings({
    DistanceSource? distanceSource,
    double? stepLength,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (distanceSource != null) {
      _distanceSource = distanceSource;
      await prefs.setInt('distanceSource', distanceSource.index);
    }
    
    if (stepLength != null) {
      _stepLength = stepLength;
      await prefs.setDouble('stepLength', stepLength);
      _pedometerService.setAverageStepLength(stepLength);
    }
    
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

      // Создаём новую прогулку с текущими настройками
      _currentWalk = Walk(
        startTime: DateTime.now(),
        distanceSource: _distanceSource,
        stepLength: _stepLength,
      );
      _isTracking = true;
      _pauseStartTime = null;
      _totalPauseDuration = Duration.zero; // Сбрасываем время пауз

      // Получаем начальную позицию
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _currentWalk!.points.add(position);
      }

      // Подписываемся на обновления позиции
      _positionSubscription = _locationService.positionStream.listen((point) {
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
      _positionSubscription?.cancel();
      _positionSubscription = null;
      _locationService.stopTracking();

      _currentWalk!.endTime = DateTime.now();
      _currentWalk!.steps = steps;
      
      // Сохраняем суммарное время паузы для корректного расчёта скорости
      // Если сейчас на паузе - добавляем текущую паузу
      if (_pauseStartTime != null) {
        _totalPauseDuration += DateTime.now().difference(_pauseStartTime!);
      }
      _currentWalk!.totalPauseDuration = _totalPauseDuration;

      // Сохраняем прогулку
      await _storageService.saveWalk(_currentWalk!);

      // Добавляем метаданные в начало списка
      _walksHistory.insert(0, WalkMetadata.fromWalk(_currentWalk!));
      _totalCount++;
      
      // Инвалидируем кэш деталей
      _walksCache.remove(_currentWalk!.id);
      
      _currentWalk = null;
      _pauseStartTime = null;
      _totalPauseDuration = Duration.zero; // Сбрасываем время пауз

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
    if (_isTracking && _currentWalk != null) {
      _pauseStartTime = DateTime.now(); // Запоминаем когда началась пауза
      _isTracking = false;
      notifyListeners();
    }
  }

  /// Продолжить прогулку
  Future<void> resumeWalk() async {
    if (_currentWalk != null && !_isTracking) {
      // Добавляем время текущей паузы к общему времени пауз
      if (_pauseStartTime != null) {
        _totalPauseDuration += DateTime.now().difference(_pauseStartTime!);
        _pauseStartTime = null;
      }
      
      _isTracking = true;
      // Переподписываемся на стрим, если нужно
      _positionSubscription ??= _locationService.positionStream.listen((point) {
        if (_isTracking && _currentWalk != null) {
          _currentWalk!.points.add(point);
          notifyListeners();
        }
      });
      notifyListeners();
    }
  }

  /// Отменить текущую прогулку
  void cancelWalk() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationService.stopTracking();
    _currentWalk = null;
    _isTracking = false;
    _pauseStartTime = null;
    _totalPauseDuration = Duration.zero;
    notifyListeners();
  }

  /// Обновить шаги в текущей прогулке
  void updateSteps(int steps) {
    if (_currentWalk != null) {
      _currentWalk!.steps = steps;
      notifyListeners();
    }
  }

  /// Обновить статистику объектов карты
  void updateObjectStats({
    int? objectsAdded,
    int? objectsConfirmed,
    int? objectsDenied,
    int? objectsCleaned,
    int? creaturesCaught,
    int? secretsRead,
    int? pointsEarned,
  }) {
    if (_currentWalk != null) {
      _currentWalk!.objectStats = _currentWalk!.objectStats.copyWith(
        objectsAdded: objectsAdded != null 
            ? _currentWalk!.objectStats.objectsAdded + objectsAdded 
            : null,
        objectsConfirmed: objectsConfirmed != null 
            ? _currentWalk!.objectStats.objectsConfirmed + objectsConfirmed 
            : null,
        objectsDenied: objectsDenied != null 
            ? _currentWalk!.objectStats.objectsDenied + objectsDenied 
            : null,
        objectsCleaned: objectsCleaned != null 
            ? _currentWalk!.objectStats.objectsCleaned + objectsCleaned 
            : null,
        creaturesCaught: creaturesCaught != null 
            ? _currentWalk!.objectStats.creaturesCaught + creaturesCaught 
            : null,
        secretsRead: secretsRead != null 
            ? _currentWalk!.objectStats.secretsRead + secretsRead 
            : null,
        pointsEarned: pointsEarned != null 
            ? _currentWalk!.objectStats.pointsEarned + pointsEarned 
            : null,
      );
      notifyListeners();
    }
  }

  /// Зафиксировать добавление объекта
  void recordObjectAdded(int points) {
    updateObjectStats(objectsAdded: 1, pointsEarned: points);
  }

  /// Зафиксировать подтверждение объекта
  void recordObjectConfirmed() {
    updateObjectStats(objectsConfirmed: 1, pointsEarned: 5);
  }

  /// Зафиксировать опровержение объекта
  void recordObjectDenied() {
    updateObjectStats(objectsDenied: 1);
  }

  /// Зафиксировать уборку монстра
  void recordMonsterCleaned(int points) {
    updateObjectStats(objectsCleaned: 1, pointsEarned: points);
  }

  /// Зафиксировать поимку существа
  void recordCreatureCaught(int points) {
    updateObjectStats(creaturesCaught: 1, pointsEarned: points);
  }

  /// Зафиксировать чтение секрета
  void recordSecretRead() {
    updateObjectStats(secretsRead: 1, pointsEarned: 10);
  }

  /// Удалить прогулку из истории
  Future<bool> deleteWalk(String walkId) async {
    try {
      await _storageService.deleteWalk(walkId);
      _walksHistory.removeWhere((m) => m.id == walkId);
      _walksCache.remove(walkId);
      _totalCount = (_totalCount - 1).clamp(0, _totalCount);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка удаления прогулки: $e';
      notifyListeners();
      return false;
    }
  }

  /// Очистить всю историю прогулок
  Future<bool> clearAllWalks() async {
    try {
      await _storageService.deleteAllWalks();
      _walksHistory.clear();
      _walksCache.clear();
      _totalCount = 0;
      _hasMore = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка очистки истории: $e';
      notifyListeners();
      return false;
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
    _positionSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}
