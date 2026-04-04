import 'package:uuid/uuid.dart';
import 'walk_point.dart';
import 'dart:math' as math;

/// Источник расстояния
enum DistanceSource {
  gps,
  pedometer,
  average,
}

/// Статистика по объектам карты за прогулку
class WalkObjectStats {
  final int objectsAdded;        // Добавлено объектов
  final int objectsConfirmed;    // Подтверждено
  final int objectsDenied;       // Опровергнуто
  final int objectsCleaned;      // Убрано монстров
  final int creaturesCaught;     // Поймано существ
  final int secretsRead;         // Прочитано секретов
  final int pointsEarned;        // Заработано очков

  const WalkObjectStats({
    this.objectsAdded = 0,
    this.objectsConfirmed = 0,
    this.objectsDenied = 0,
    this.objectsCleaned = 0,
    this.creaturesCaught = 0,
    this.secretsRead = 0,
    this.pointsEarned = 0,
  });

  int get totalActions => 
      objectsAdded + objectsConfirmed + objectsCleaned + creaturesCaught + secretsRead;

  Map<String, dynamic> toMap() => {
    'objectsAdded': objectsAdded,
    'objectsConfirmed': objectsConfirmed,
    'objectsDenied': objectsDenied,
    'objectsCleaned': objectsCleaned,
    'creaturesCaught': creaturesCaught,
    'secretsRead': secretsRead,
    'pointsEarned': pointsEarned,
  };

  factory WalkObjectStats.fromMap(Map<String, dynamic> map) {
    return WalkObjectStats(
      objectsAdded: map['objectsAdded'] as int? ?? 0,
      objectsConfirmed: map['objectsConfirmed'] as int? ?? 0,
      objectsDenied: map['objectsDenied'] as int? ?? 0,
      objectsCleaned: map['objectsCleaned'] as int? ?? 0,
      creaturesCaught: map['creaturesCaught'] as int? ?? 0,
      secretsRead: map['secretsRead'] as int? ?? 0,
      pointsEarned: map['pointsEarned'] as int? ?? 0,
    );
  }

  WalkObjectStats copyWith({
    int? objectsAdded,
    int? objectsConfirmed,
    int? objectsDenied,
    int? objectsCleaned,
    int? creaturesCaught,
    int? secretsRead,
    int? pointsEarned,
  }) {
    return WalkObjectStats(
      objectsAdded: objectsAdded ?? this.objectsAdded,
      objectsConfirmed: objectsConfirmed ?? this.objectsConfirmed,
      objectsDenied: objectsDenied ?? this.objectsDenied,
      objectsCleaned: objectsCleaned ?? this.objectsCleaned,
      creaturesCaught: creaturesCaught ?? this.creaturesCaught,
      secretsRead: secretsRead ?? this.secretsRead,
      pointsEarned: pointsEarned ?? this.pointsEarned,
    );
  }
}

/// Модель прогулки
class Walk {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  final List<WalkPoint> points;
  int steps;
  String? name;
  String? notes;
  
  /// Источник расстояния (приоритет педометра)
  final DistanceSource distanceSource;
  
  /// Длина шага в метрах (для расчёта расстояния)
  final double stepLength;

  /// Статистика по объектам карты
  WalkObjectStats objectStats;

  Walk({
    String? id,
    required this.startTime,
    this.endTime,
    List<WalkPoint>? points,
    this.steps = 0,
    this.name,
    this.notes,
    this.distanceSource = DistanceSource.pedometer,
    this.stepLength = 0.75,
    WalkObjectStats? objectStats,
  })  : id = id ?? const Uuid().v4(),
        points = points ?? [],
        objectStats = objectStats ?? const WalkObjectStats();

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
      return '$hoursч $minutesмин';
    } else if (minutes > 0) {
      return '$minutesмин $secondsсек';
    }
    return '$secondsсек';
  }

  /// Общее расстояние в метрах
  /// Приоритет педометра: используем шаги * длину шага
  double get totalDistance {
    // Если есть шаги и источник не GPS - используем педометр
    if (steps > 0 && distanceSource != DistanceSource.gps) {
      if (distanceSource == DistanceSource.pedometer) {
        // Только pedometer
        return steps * stepLength;
      } else {
        // Average: среднее между GPS и pedometer
        final gpsDist = _calculateGpsDistance();
        final pedometerDist = steps * stepLength;
        return (gpsDist + pedometerDist) / 2;
      }
    }
    // Otherwise GPS
    return _calculateGpsDistance();
  }
  
  /// Расстояние по GPS
  double get gpsDistance => _calculateGpsDistance();
  
  /// Внутренний метод расчёта GPS расстояния
  double _calculateGpsDistance() {
    if (points.length < 2) return 0;
    
    double distance = 0;
    for (int i = 1; i < points.length; i++) {
      final segmentDistance = _haversineDistance(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
      distance += segmentDistance;
    }
    return distance;
  }

  /// Расстояние по шагомеру
  double get pedometerDistance => steps * stepLength;

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
    final secs = duration.inSeconds;
    if (secs == 0) return 0;
    final hours = secs / 3600.0;
    if (hours == 0) return 0;
    return (totalDistance / 1000) / hours;
  }

  /// Форматированная средняя скорость
  String get formattedSpeed {
    return '${averageSpeed.toStringAsFixed(1)} км/ч';
  }

  /// Источник расстояния (для отображения)
  String get distanceSourceLabel {
    switch (distanceSource) {
      case DistanceSource.gps:
        return 'GPS';
      case DistanceSource.pedometer:
        return 'Шагомер';
      case DistanceSource.average:
        return 'Среднее';
    }
  }

  /// Расчёт расстояния между двумя точками (формула Гаверсинуса)
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // в метрах
    
    // Переводим градусы в радианы
    final double lat1Rad = lat1 * math.pi / 180;
    final double lat2Rad = lat2 * math.pi / 180;
    final double deltaLatRad = (lat2 - lat1) * math.pi / 180;
    final double deltaLonRad = (lon2 - lon1) * math.pi / 180;

    // Формула Гаверсинуса
    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
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
      'distanceSource': distanceSource.index,
      'stepLength': stepLength,
      'objectStats': objectStats.toMap(),
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
      distanceSource: DistanceSource.values[map['distanceSource'] as int? ?? 1],
      stepLength: (map['stepLength'] as num?)?.toDouble() ?? 0.75,
      objectStats: map['objectStats'] != null
          ? WalkObjectStats.fromMap(map['objectStats'] as Map<String, dynamic>)
          : null,
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
    DistanceSource? distanceSource,
    double? stepLength,
    WalkObjectStats? objectStats,
  }) {
    return Walk(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      points: points ?? List.from(this.points),
      steps: steps ?? this.steps,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      distanceSource: distanceSource ?? this.distanceSource,
      stepLength: stepLength ?? this.stepLength,
      objectStats: objectStats ?? this.objectStats,
    );
  }

  @override
  String toString() {
    return 'Walk(id: $id, startTime: $startTime, distance: $formattedDistance, steps: $steps, source: $distanceSourceLabel)';
  }
}
