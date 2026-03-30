/// Точка маршрута прогулки
class WalkPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double accuracy;
  final DateTime timestamp;
  final double heading; // Направление движения в градусах (0-360)

  const WalkPoint({
    required this.latitude,
    required this.longitude,
    this.altitude = 0,
    this.speed = 0,
    this.accuracy = 0,
    required this.timestamp,
    this.heading = 0,
  });

  /// Преобразование в формат для Яндекс карт
  double get lat => latitude;
  double get lon => longitude;

  /// Преобразование в Map для сохранения
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'heading': heading,
    };
  }

  /// Создание из Map
  factory WalkPoint.fromMap(Map<String, dynamic> map) {
    return WalkPoint(
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.parse(map['timestamp'] as String),
      heading: (map['heading'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Копировать с новыми значениями
  WalkPoint copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    double? speed,
    double? accuracy,
    DateTime? timestamp,
    double? heading,
  }) {
    return WalkPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      heading: heading ?? this.heading,
    );
  }

  @override
  String toString() {
    return 'WalkPoint(lat: $latitude, lon: $longitude, time: $timestamp)';
  }
}
