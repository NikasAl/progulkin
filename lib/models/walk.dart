import 'package:uuid/uuid.dart';
import 'walk_point.dart';

/// Модель прогулки
class Walk {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  final List<WalkPoint> points;
  int steps;
  String? name;
  String? notes;

  Walk({
    String? id,
    required this.startTime,
    this.endTime,
    List<WalkPoint>? points,
    this.steps = 0,
    this.name,
    this.notes,
  })  : id = id ?? const Uuid().v4(),
        points = points ?? [];

  /// Продолжительность прогулки
  Duration get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return DateTime.now().difference(startTime);
  }

  /// Форматированная продолжительность
  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}ч ${minutes}мин';
    } else if (minutes > 0) {
      return '${minutes}мин ${seconds}сек';
    }
    return '${seconds}сек';
  }

  /// Общее расстояние в метрах
  double get totalDistance {
    if (points.length < 2) return 0;
    
    double distance = 0;
    for (int i = 1; i < points.length; i++) {
      distance += _calculateDistance(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return distance;
  }

  /// Форматированное расстояние
  String get formattedDistance {
    final dist = totalDistance;
    if (dist >= 1000) {
      return '${(dist / 1000).toStringAsFixed(2)} км';
    }
    return '${dist.toStringAsFixed(0)} м';
  }

  /// Средняя скорость в км/ч
  double get averageSpeed {
    if (duration.inSeconds == 0) return 0;
    return (totalDistance / 1000) / (duration.inSeconds / 3600);
  }

  /// Форматированная средняя скорость
  String get formattedSpeed {
    return '${averageSpeed.toStringAsFixed(1)} км/ч';
  }

  /// Расчёт расстояния между двумя точками (формула Гаверсинуса)
  double _calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371000; // в метрах
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = (dLat / 2).abs() * (dLat / 2).abs() +
        _toRadians(lat1).abs() * _toRadians(lat2).abs() *
        (dLon / 2).abs() * (dLon / 2).abs();
    
    final double c = 2 * (a.abs() > 0 ? a : 0.0001).abs();
    
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * 0.017453292519943295;
  }

  /// Активна ли прогулка
  bool get isActive => endTime == null;

  /// Преобразование в Map для сохранения
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'points': points.map((p) => p.toMap()).toList(),
      'steps': steps,
      'name': name,
      'notes': notes,
    };
  }

  /// Создание из Map
  factory Walk.fromMap(Map<String, dynamic> map) {
    return Walk(
      id: map['id'] as String,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null 
          ? DateTime.parse(map['endTime'] as String) 
          : null,
      points: (map['points'] as List<dynamic>?)
          ?.map((p) => WalkPoint.fromMap(p as Map<String, dynamic>))
          .toList() ?? [],
      steps: map['steps'] as int? ?? 0,
      name: map['name'] as String?,
      notes: map['notes'] as String?,
    );
  }

  /// Копирование с обновлением
  Walk copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    List<WalkPoint>? points,
    int? steps,
    String? name,
    String? notes,
  }) {
    return Walk(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      points: points ?? List.from(this.points),
      steps: steps ?? this.steps,
      name: name ?? this.name,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'Walk(id: $id, startTime: $startTime, distance: $formattedDistance, steps: $steps)';
  }
}
