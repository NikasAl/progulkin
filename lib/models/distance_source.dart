/// Источник данных для расчёта расстояния
enum DistanceSource {
  gps,       // Только GPS (формула Гаверсинуса)
  pedometer, // Только педометр (шаги × длина шага)
  average,   // Среднее между GPS и педометром
}

/// Расширение для удобной работы с DistanceSource
extension DistanceSourceExtension on DistanceSource {
  String get displayName {
    switch (this) {
      case DistanceSource.gps:
        return 'GPS';
      case DistanceSource.pedometer:
        return 'Шагомер';
      case DistanceSource.average:
        return 'Среднее';
    }
  }
  
  String get description {
    switch (this) {
      case DistanceSource.gps:
        return 'Расстояние по GPS координатам';
      case DistanceSource.pedometer:
        return 'Расстояние по количеству шагов';
      case DistanceSource.average:
        return 'Среднее значение GPS и шагомера';
    }
  }
}
