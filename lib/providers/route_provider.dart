import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/planned_route.dart';
import '../di/service_locator.dart';
import '../services/p2p/map_object_storage.dart';

/// Провайдер для управления запланированными маршрутами
class RouteProvider extends ChangeNotifier {
  final MapObjectStorage _storage;

  List<PlannedRoute> _routes = [];
  PlannedRoute? _selectedRoute;
  bool _isLoading = false;
  String? _error;

  RouteProvider({MapObjectStorage? storage})
      : _storage = storage ?? getIt<MapObjectStorage>() {
    _loadRoutes();
  }

  // Геттеры
  List<PlannedRoute> get routes => _routes;
  PlannedRoute? get selectedRoute => _selectedRoute;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasSelectedRoute => _selectedRoute != null;

  /// Загрузить все маршруты
  Future<void> _loadRoutes() async {
    _isLoading = true;
    notifyListeners();

    try {
      _routes = await _storage.getAllRoutes();
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки маршрутов: $e';
      debugPrint('⚠️ $_error');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Обновить список маршрутов
  Future<void> refresh() async {
    await _loadRoutes();
  }

  /// Сохранить новый маршрут
  Future<bool> saveRoute(PlannedRoute route) async {
    try {
      await _storage.savePlannedRoute(route);
      await refresh();
      return true;
    } catch (e) {
      _error = 'Ошибка сохранения маршрута: $e';
      debugPrint('⚠️ $_error');
      notifyListeners();
      return false;
    }
  }

  /// Обновить существующий маршрут
  Future<bool> updateRoute(PlannedRoute route) async {
    try {
      await _storage.updateRoute(route);
      await refresh();
      // Если обновляем выбранный маршрут - обновляем и его
      if (_selectedRoute?.id == route.id) {
        _selectedRoute = route;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Ошибка обновления маршрута: $e';
      debugPrint('⚠️ $_error');
      notifyListeners();
      return false;
    }
  }

  /// Удалить маршрут
  Future<bool> deleteRoute(String id) async {
    try {
      await _storage.deleteRoute(id);
      // Если удаляем выбранный маршрут - снимаем выбор
      if (_selectedRoute?.id == id) {
        _selectedRoute = null;
      }
      await refresh();
      return true;
    } catch (e) {
      _error = 'Ошибка удаления маршрута: $e';
      debugPrint('⚠️ $_error');
      notifyListeners();
      return false;
    }
  }

  /// Выбрать маршрут для прогулки
  Future<void> selectRoute(PlannedRoute? route) async {
    _selectedRoute = route;

    // Обновляем время последнего использования
    if (route != null) {
      try {
        await _storage.markRouteUsed(route.id);
        await refresh();
      } catch (e) {
        debugPrint('⚠️ Ошибка обновления времени использования: $e');
      }
    }

    notifyListeners();
  }

  /// Снять выбор маршрута
  void clearSelectedRoute() {
    _selectedRoute = null;
    notifyListeners();
  }

  /// Выбрать маршрут по ID
  Future<void> selectRouteById(String? id) async {
    if (id == null) {
      clearSelectedRoute();
      return;
    }

    final route = _routes.firstWhere(
      (r) => r.id == id,
      orElse: () => _routes.first,
    );

    if (route.id == id) {
      await selectRoute(route);
    } else {
      // Пробуем загрузить из базы
      final loaded = await _storage.getRoute(id);
      if (loaded != null) {
        await selectRoute(loaded);
      } else {
        clearSelectedRoute();
      }
    }
  }

  /// Переключить избранное
  Future<void> toggleFavorite(String id) async {
    try {
      await _storage.toggleRouteFavorite(id);
      await refresh();
    } catch (e) {
      _error = 'Ошибка обновления избранного: $e';
      debugPrint('⚠️ $_error');
      notifyListeners();
    }
  }

  /// Получить избранные маршруты
  List<PlannedRoute> get favoriteRoutes =>
      _routes.where((r) => r.isFavorite).toList();

  /// Получить последние использованные маршруты
  List<PlannedRoute> get recentRoutes {
    final used = _routes.where((r) => r.lastUsedAt != null).toList();
    used.sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    return used.take(5).toList();
  }

  /// Создать маршрут из списка точек
  Future<bool> createRouteFromWaypoints({
    required String name,
    String? description,
    required List<LatLng> waypoints,
    int? colorValue,
  }) async {
    if (waypoints.length < 2) {
      _error = 'Маршрут должен содержать минимум 2 точки';
      notifyListeners();
      return false;
    }

    final route = PlannedRoute(
      name: name,
      description: description,
      waypoints: waypoints,
      colorValue: colorValue,
    );

    return await saveRoute(route);
  }

  /// Очистить ошибку
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
