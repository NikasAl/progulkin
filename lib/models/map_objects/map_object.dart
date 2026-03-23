import 'dart:convert';

/// Тип объекта на карте
enum MapObjectType {
  trashMonster('trash_monster', 'Мусорный монстр', '👹'),
  secretMessage('secret_message', 'Секретное сообщение', '📜'),
  creature('creature', 'Существо', '🦊'),
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

/// Базовый класс для всех объектов на карте
abstract class MapObject {
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
  String get geohash => _encodeGeohash(latitude, longitude, 6);

  /// Данные для P2P синхронизации
  Map<String, dynamic> toSyncJson();

  /// Создание из P2P данных
  factory MapObject.fromSyncJson(Map<String, dynamic> json) {
    final type = MapObjectType.fromCode(json['type'] as String);
    switch (type) {
      case MapObjectType.trashMonster:
        return TrashMonster.fromSyncJson(json);
      case MapObjectType.secretMessage:
        return SecretMessage.fromSyncJson(json);
      case MapObjectType.creature:
        return Creature.fromSyncJson(json);
      default:
        throw UnimplementedError('Unknown object type: $type');
    }
  }

  /// Краткое описание для списка
  String get shortDescription;

  /// Можно ли взаимодействовать в данной точке
  bool canInteractAt(double lat, double lng, {double radiusMeters = 100});

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

  /// Базовые данные для JSON
  Map<String, dynamic> baseJson() {
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

  /// Простой geohash (до 6 символов = ~1.2км точность)
  static String _encodeGeohash(double lat, double lng, int precision) {
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

/// Расчёт расстояния между точками
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371000;
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
