import 'dart:math' as math;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

/// Запланированный маршрут прогулки
class PlannedRoute {
  final String id;
  final String name;
  final String? description;
  final List<LatLng> waypoints;
  final double distance; // в метрах
  final int estimatedMinutes; // время ходьбы при 5 км/ч
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final int colorValue; // цвет для отображения на карте
  final bool isFavorite;

  PlannedRoute({
    String? id,
    required this.name,
    this.description,
    required this.waypoints,
    double? distance,
    int? estimatedMinutes,
    DateTime? createdAt,
    this.lastUsedAt,
    int? colorValue,
    this.isFavorite = false,
  })  : id = id ?? const Uuid().v4(),
        distance = distance ?? _calculateDistance(waypoints),
        estimatedMinutes = estimatedMinutes ?? _estimateMinutes(distance ?? _calculateDistance(waypoints)),
        createdAt = createdAt ?? DateTime.now(),
        colorValue = colorValue ?? _defaultColor;

  static const int _defaultColor = 0xFF2196F3; // синий

  /// Расчёт расстояния по точкам
  static double _calculateDistance(List<LatLng> waypoints) {
    if (waypoints.length < 2) return 0;

    double total = 0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += _haversineDistance(
        waypoints[i].latitude,
        waypoints[i].longitude,
        waypoints[i + 1].latitude,
        waypoints[i + 1].longitude,
      );
    }
    return total;
  }

  /// Оценка времени ходьбы (5 км/ч = 83.3 м/мин)
  static int _estimateMinutes(double distance) {
    if (distance < 100) return 1;
    return (distance / 83.3).round();
  }

  /// Формула Гаверсинуса
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;

    final double lat1Rad = lat1 * math.pi / 180;
    final double lat2Rad = lat2 * math.pi / 180;
    final double deltaLatRad = (lat2 - lat1) * math.pi / 180;
    final double deltaLonRad = (lon2 - lon1) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Форматированное расстояние
  String get formattedDistance {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} км';
    }
    return '${distance.toStringAsFixed(0)} м';
  }

  /// Форматированное время
  String get formattedTime {
    if (estimatedMinutes < 60) {
      return '~$estimatedMinutes мин';
    }
    final hours = estimatedMinutes ~/ 60;
    final mins = estimatedMinutes % 60;
    if (mins == 0) return '~$hours ч';
    return '~$hours ч $mins мин';
  }

  /// Количество точек
  int get waypointCount => waypoints.length;

  /// Начальная точка
  LatLng? get start => waypoints.isNotEmpty ? waypoints.first : null;

  /// Конечная точка
  LatLng? get end => waypoints.isNotEmpty ? waypoints.last : null;

  /// Преобразование в Map для SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'waypoints': jsonEncode(waypoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList()),
      'distance': distance,
      'estimated_minutes': estimatedMinutes,
      'created_at': createdAt.toIso8601String(),
      'last_used_at': lastUsedAt?.toIso8601String(),
      'color': colorValue,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  /// Создание из Map
  factory PlannedRoute.fromMap(Map<String, dynamic> map) {
    final waypointsJson = jsonDecode(map['waypoints'] as String) as List<dynamic>;
    final waypoints = waypointsJson.map((p) {
      final point = p as Map<String, dynamic>;
      return LatLng(point['lat'] as double, point['lng'] as double);
    }).toList();

    return PlannedRoute(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      waypoints: waypoints,
      distance: (map['distance'] as num?)?.toDouble(),
      estimatedMinutes: map['estimated_minutes'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastUsedAt: map['last_used_at'] != null
          ? DateTime.parse(map['last_used_at'] as String)
          : null,
      colorValue: map['color'] as int?,
      isFavorite: (map['is_favorite'] as int?) == 1,
    );
  }

  /// Копирование с обновлением
  PlannedRoute copyWith({
    String? id,
    String? name,
    String? description,
    List<LatLng>? waypoints,
    double? distance,
    int? estimatedMinutes,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int? colorValue,
    bool? isFavorite,
  }) {
    return PlannedRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      waypoints: waypoints ?? List.from(this.waypoints),
      distance: distance ?? this.distance,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      colorValue: colorValue ?? this.colorValue,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  String toString() {
    return 'PlannedRoute(id: $id, name: $name, waypoints: $waypointCount, distance: $formattedDistance)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlannedRoute && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
