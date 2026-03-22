/// Точка маршрута прогулки
class WalkPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double accuracy;
  final DateTime timestamp;

  const WalkPoint({
    required this.latitude,
    required this.longitude,
    this.altitude = 0,
    this.speed = 0,
    this.accuracy = 0,
    required this.timestamp,
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
    );
  }

  @override
  String toString() {
    return 'WalkPoint(lat: $latitude, lon: $longitude, time: $timestamp)';
  }
}
