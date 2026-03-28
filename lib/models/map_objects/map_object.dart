import 'dart:math';
import 'dart:convert';

/// Тип объекта на карте
enum MapObjectType {
  trashMonster('trash_monster', 'Мусорный монстр', '👹'),
  secretMessage('secret_message', 'Секретное сообщение', '📜'),
  creature('creature', 'Существо', '🦊'),
  interestNote('interest_note', 'Заметка', '📍'),
  reminderCharacter('reminder_character', 'Напоминалка', '🔔'),
  checkpoint('checkpoint', 'Контрольная точка', '🏁'),
  event('event', 'Событие', '🎉'),
  ;

  final String code;
  final String name;
  final String emoji;

  const MapObjectType(this.code, this.name, this.emoji);

  static MapObjectType fromCode(String code) {
    return MapObjectType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => MapObjectType.trashMonster,
    );
  }
}

/// Статус объекта
enum MapObjectStatus {
  active('active'),
  confirmed('confirmed'),
  cleaned('cleaned'),
  expired('expired'),
  hidden('hidden'),
  ;

  final String code;
  const MapObjectStatus(this.code);

  static MapObjectStatus fromCode(String code) {
    return MapObjectStatus.values.firstWhere(
      (t) => t.code == code,
      orElse: () => MapObjectStatus.active,
    );
  }
}

/// Расширения для MapObjectType
extension MapObjectTypeExtension on MapObjectType {
  String get emoji {
    switch (this) {
      case MapObjectType.trashMonster:
        return '👹';
      case MapObjectType.secretMessage:
        return '📜';
      case MapObjectType.creature:
        return '🦊';
      case MapObjectType.interestNote:
        return '📍';
      case MapObjectType.reminderCharacter:
        return '🔔';
      case MapObjectType.checkpoint:
        return '🏁';
      case MapObjectType.event:
        return '🎉';
    }
  }
}

/// Базовый класс для всех объектов на карте
class MapObject {
  final String id;
  final MapObjectType type;
  final double latitude;
  final double longitude;
  final String ownerId;
  final String ownerName;
  final int ownerReputation;
  final DateTime createdAt;
  final DateTime? expiresAt;
  MapObjectStatus status;
  int confirms;
  int denies;
  int views;
  int version;

  MapObject({
    required this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.ownerId,
    this.ownerName = 'Аноним',
    this.ownerReputation = 0,
    DateTime? createdAt,
    this.expiresAt,
    this.status = MapObjectStatus.active,
    this.confirms = 0,
    this.denies = 0,
    this.views = 0,
    this.version = 1,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Уникальный идентификатор для синхронизации
  String get syncId => '${type.code}_$id';

  /// Geohash для зонной синхронизации
  String get geohash => encodeGeohash(latitude, longitude, 6);

  /// Данные для P2P синхронизации
  Map<String, dynamic> toSyncJson() {
    return {
      'id': id,
      'type': type.code,
      'latitude': latitude,
      'longitude': longitude,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerReputation': ownerReputation,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'status': status.code,
      'confirms': confirms,
      'denies': denies,
      'views': views,
      'version': version,
    };
  }

  /// Создание из P2P данных - использует фабрику из map_objects.dart
  static MapObject fromSyncJson(Map<String, dynamic> json) {
    // Фабрика определена в map_objects.dart для избежания циклического импорта
    return _createMapObjectFromJson(json);
  }
  
  /// Функция создания (устанавливается из map_objects.dart)
  static MapObject Function(Map<String, dynamic>) _createMapObjectFromJson = _defaultFromJson;
  
  static MapObject _defaultFromJson(Map<String, dynamic> json) {
    return fromJson(json);
  }
  
  /// Установить фабрику создания (вызывается из map_objects.dart)
  static void setObjectFactory(MapObject Function(Map<String, dynamic>) factory) {
    _createMapObjectFromJson = factory;
  }

  /// Базовое создание из JSON (публичный метод)
  static MapObject fromJson(Map<String, dynamic> json) {
    return MapObject(
      id: json['id'] as String,
      type: MapObjectType.fromCode(json['type'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      ownerId: json['ownerId'] as String,
      ownerName: json['ownerName'] as String? ?? 'Аноним',
      ownerReputation: json['ownerReputation'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      status: MapObjectStatus.fromCode(json['status'] as String? ?? 'active'),
      confirms: json['confirms'] as int? ?? 0,
      denies: json['denies'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
    );
  }

  /// Краткое описание для списка
  String get shortDescription => '${type.emoji} ${type.name}';

  /// Можно ли взаимодействовать в данной точке
  bool canInteractAt(double lat, double lng, {double radiusMeters = 100}) {
    final distance = calculateDistance(latitude, longitude, lat, lng);
    return distance <= radiusMeters;
  }

  /// Проверка, истёк ли срок действия
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Доверенный ли объект (много подтверждений, мало отрицаний)
  bool get isTrusted => confirms >= 3 && (denies < confirms / 2);

  /// Скрыть объект (слишком много жалоб)
  bool get shouldBeHidden => denies >= 5 && denies > confirms;

  /// Обновить версию при изменении
  void incrementVersion() {
    version++;
  }

  /// Кодирование geohash
  static String encodeGeohash(double lat, double lng, int precision) {
    const chars = '0123456789bcdefghjkmnpqrstuvwxyz';
    String hash = '';
    int bit = 0;
    int ch = 0;
    double minLat = -90, maxLat = 90;
    double minLng = -180, maxLng = 180;

    while (hash.length < precision) {
      if (bit % 2 == 0) {
        final mid = (minLng + maxLng) / 2;
        if (lng > mid) {
          ch |= (1 << (4 - bit % 5));
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat > mid) {
          ch |= (1 << (4 - bit % 5));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      bit++;
      if (bit % 5 == 0) {
        hash += chars[ch];
        ch = 0;
      }
    }
    return hash;
  }

  @override
  String toString() => '$type#$id at ($latitude, $longitude)';
}

/// Расчёт расстояния между точками (в метрах)
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371000; // метры
  
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  
  final a = 0.5 -
      0.5 * _cos(dLat) +
      0.5 * _cos(_toRadians(lat1)) *
          _cos(_toRadians(lat2)) *
          (1 - _cos(dLon));
  
  return earthRadius * 2 * _asin(_sqrt(a));
}

double _toRadians(double degree) => degree * 0.017453292519943295;
double _cos(double x) => x.abs() < 1e-10 ? 1 : (1 - x * x / 2);
double _asin(double x) => x.abs() < 1e-10 ? x : x + x * x * x / 6;
double _sqrt(double x) => x < 0 ? 0 : x;
