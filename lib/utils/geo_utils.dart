import 'dart:math' as math;

/// Гео-утилиты для расчёта расстояний, направлений и других операций с координатами
///
/// Все методы используют формулу Haversine для расчёта расстояний
/// на поверхности Земли с учётом её кривизны.

/// Радиус Земли в метрах
const double earthRadiusMeters = 6371000;

/// Рассчитать расстояние между двумя точками в метрах
///
/// Использует формулу Haversine для расчёта кратчайшего расстояния
/// между двумя точками на поверхности сферы.
///
/// Параметры:
/// - [lat1], [lon1] - координаты первой точки в градусах
/// - [lat2], [lon2] - координаты второй точки в градусах
///
/// Возвращает расстояние в метрах.
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  final double dLat = _toRadians(lat2 - lat1);
  final double dLon = _toRadians(lon2 - lon1);

  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);

  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return earthRadiusMeters * c;
}

/// Рассчитать азимут (направление) от одной точки к другой
///
/// Азимут измеряется в градусах от 0 до 360, где 0 - север,
/// 90 - восток, 180 - юг, 270 - запад.
///
/// Параметры:
/// - [lat1], [lon1] - координаты начальной точки в градусах
/// - [lat2], [lon2] - координаты конечной точки в градусах
///
/// Возвращает азимут в градусах.
double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
  final double lat1Rad = _toRadians(lat1);
  final double lat2Rad = _toRadians(lat2);
  final double dLon = _toRadians(lon2 - lon1);

  final double y = math.sin(dLon) * math.cos(lat2Rad);
  final double x = math.cos(lat1Rad) * math.sin(lat2Rad) -
      math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

  final double bearing = math.atan2(y, x) * 180 / math.pi;
  return (bearing + 360) % 360;
}

/// Рассчитать конечную точку по начальной точке, азимуту и расстоянию
///
/// Полезно для расчёта позиции спавна существ в радиусе от центра.
///
/// Параметры:
/// - [lat], [lon] - координаты начальной точки в градусах
/// - [bearing] - азимут в градусах
/// - [distanceMeters] - расстояние в метрах
///
/// Возвращает (latitude, longitude) в градусах.
({double lat, double lon}) calculateDestination(
  double lat,
  double lon,
  double bearing,
  double distanceMeters,
) {
  final double lat1 = _toRadians(lat);
  final double lon1 = _toRadians(lon);
  final double brng = _toRadians(bearing);
  final double d = distanceMeters / earthRadiusMeters;

  final double lat2 = math.asin(
    math.sin(lat1) * math.cos(d) +
        math.cos(lat1) * math.sin(d) * math.cos(brng),
  );

  final double lon2 = lon1 +
      math.atan2(
        math.sin(brng) * math.sin(d) * math.cos(lat1),
        math.cos(d) - math.sin(lat1) * math.sin(lat2),
      );

  return (lat: lat2 * 180 / math.pi, lon: lon2 * 180 / math.pi);
}

/// Генерировать случайную точку в радиусе от центра
///
/// Полезно для спавна существ и других игровых объектов.
///
/// Параметры:
/// - [centerLat], [centerLon] - координаты центра в градусах
/// - [radiusMeters] - радиус в метрах
/// - [random] - опциональный генератор случайных чисел (для тестов)
///
/// Возвращает (latitude, longitude) в градусах.
({double lat, double lon}) randomPointInRadius(
  double centerLat,
  double centerLon,
  double radiusMeters, [
  math.Random? random,
]) {
  final r = random ?? math.Random();

  // Случайный угол
  final angle = r.nextDouble() * 2 * math.pi;

  // Случайное расстояние (с коррекцией для равномерного распределения)
  final distance = radiusMeters * math.sqrt(r.nextDouble());

  // Азимут в градусах
  final bearing = angle * 180 / math.pi;

  return calculateDestination(centerLat, centerLon, bearing, distance);
}

/// Проверить, находится ли точка в радиусе от другой точки
///
/// Параметры:
/// - [lat1], [lon1] - координаты центра в градусах
/// - [lat2], [lon2] - координаты проверяемой точки в градусах
/// - [radiusMeters] - радиус в метрах
///
/// Возвращает true, если точка находится в радиусе.
bool isWithinRadius(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
  double radiusMeters,
) {
  return calculateDistance(lat1, lon1, lat2, lon2) <= radiusMeters;
}

/// Рассчитать скорость между двумя точками
///
/// Параметры:
/// - [lat1], [lon1] - координаты первой точки
/// - [lat2], [lon2] - координаты второй точки
/// - [timeDiffSeconds] - разница во времени в секундах
///
/// Возвращает скорость в м/с.
double calculateSpeed(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
  int timeDiffSeconds,
) {
  if (timeDiffSeconds <= 0) return 0;
  final distance = calculateDistance(lat1, lon1, lat2, lon2);
  return distance / timeDiffSeconds;
}

/// Форматировать расстояние для отображения
///
/// Возвращает строку с расстоянием в метрах или километрах.
String formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.toStringAsFixed(0)} м';
  }
  return '${(meters / 1000).toStringAsFixed(2)} км';
}

/// Форматировать скорость для отображения
///
/// Возвращает строку со скоростью в км/ч.
String formatSpeed(double metersPerSecond) {
  final kmh = metersPerSecond * 3.6;
  return '${kmh.toStringAsFixed(1)} км/ч';
}

/// Преобразовать градусы в радианы
double _toRadians(double degrees) => degrees * math.pi / 180;

/// Преобразовать радианы в градусы
double toDegrees(double radians) => radians * 180 / math.pi;
