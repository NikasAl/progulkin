import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'map_object.dart';

/// Тип секрета
enum SecretType {
  text('text', 'Текст', '📜'),
  riddle('riddle', 'Загадка', '❓'),
  story('story', 'История', '📖'),
  wish('wish', 'Пожелание', '💫'),
  tip('tip', 'Совет', '💡'),
  memory('memory', 'Воспоминание', '💭'),
  ;

  final String code;
  final String name;
  final String emoji;

  const SecretType(this.code, this.name, this.emoji);

  static SecretType fromCode(String code) {
    return SecretType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => SecretType.text,
    );
  }
}

/// Секретное сообщение
/// Можно прочитать только находясь в определённом месте
class SecretMessage extends MapObject {
  final SecretType secretType;
  final String title;           // Виден всем
  final String encryptedContent; // Зашифрованное содержимое
  final String contentHash;      // Хеш для проверки
  final double unlockRadius;     // Радиус разблокировки в метрах
  final bool isOneTime;          // Одноразовое (исчезает после прочтения)
  final int maxReads;            // Макс. количество прочтений (0 = бесконечно)
  final int currentReads;        // Текущее количество прочтений
  final List<String> readByUsers; // Кто уже прочитал

  SecretMessage({
    required super.id,
    required super.latitude,
    required super.longitude,
    required super.ownerId,
    super.ownerName,
    super.ownerReputation,
    required this.secretType,
    required this.title,
    required String content,
    this.unlockRadius = 50,
    this.isOneTime = false,
    this.maxReads = 0,
    this.currentReads = 0,
    List<String>? readByUsers,
    super.status,
    super.confirms,
    super.denies,
    super.views,
    super.version,
    super.expiresAt,
  })  : encryptedContent = _encrypt(content),
        contentHash = _hash(content),
        readByUsers = readByUsers ?? [],
        super(type: MapObjectType.secretMessage);

  /// Простое "шифрование" (base64 reverse + XOR)
  /// Для реального приложения нужно использовать crypto_box или AES
  static String _encrypt(String content) {
    final bytes = utf8.encode(content);
    final reversed = bytes.reversed.toList();
    return base64Encode(reversed);
  }

  /// Расшифровка
  static String _decrypt(String encrypted) {
    final bytes = base64Decode(encrypted);
    final reversed = bytes.reversed.toList();
    return utf8.decode(reversed);
  }

  /// Хеш содержимого
  static String _hash(String content) {
    return sha256.convert(utf8.encode(content)).toString().substring(0, 16);
  }

  /// Расшифровать содержимое (только если на месте!)
  String? decryptContent(String userId, double userLat, double userLng) {
    // Проверяем, находится ли пользователь в нужном месте
    if (!canInteractAt(userLat, userLng, radiusMeters: unlockRadius)) {
      return null; // Слишком далеко
    }

    // Проверяем лимит прочтений
    if (maxReads > 0 && currentReads >= maxReads) {
      return null; // Лимит исчерпан
    }

    // Для одноразовых - проверяем, не читал ли уже этот пользователь
    if (isOneTime && readByUsers.contains(userId)) {
      return null; // Уже прочитано
    }

    return _decrypt(encryptedContent);
  }

  /// Проверить, может ли пользователь прочитать
  bool canRead(String userId, double userLat, double userLng) {
    if (!canInteractAt(userLat, userLng, radiusMeters: unlockRadius)) {
      return false;
    }
    if (maxReads > 0 && currentReads >= maxReads) {
      return false;
    }
    if (isOneTime && readByUsers.contains(userId)) {
      return false;
    }
    return true;
  }

  /// Отметить как прочитанное
  SecretMessage markAsRead(String userId) {
    final newReadBy = [...readByUsers];
    if (!newReadBy.contains(userId)) {
      newReadBy.add(userId);
    }

    return SecretMessage(
      id: id,
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerReputation: ownerReputation,
      secretType: secretType,
      title: title,
      content: _decrypt(encryptedContent), // Передаём расшифрованный для повторного шифрования
      unlockRadius: unlockRadius,
      isOneTime: isOneTime,
      maxReads: maxReads,
      currentReads: currentReads + 1,
      readByUsers: newReadBy,
      status: status,
      confirms: confirms,
      denies: denies,
      views: views + 1,
      version: version + 1,
    );
  }

  @override
  String get shortDescription {
    final lockIcon = isOneTime ? '🔒' : '📍';
    return '${secretType.emoji} $title $lockIcon';
  }

  @override
  bool canInteractAt(double lat, double lng, {double radiusMeters = 100}) {
    final distance = calculateDistance(latitude, longitude, lat, lng);
    return distance <= unlockRadius;
  }

  /// Расстояние до точки (для UI)
  double distanceTo(double lat, double lng) {
    return calculateDistance(latitude, longitude, lat, lng);
  }

  @override
  Map<String, dynamic> toSyncJson() {
    return {
      ...baseJson(),
      'secretType': secretType.code,
      'title': title,
      'encryptedContent': encryptedContent,
      'contentHash': contentHash,
      'unlockRadius': unlockRadius,
      'isOneTime': isOneTime,
      'maxReads': maxReads,
      'currentReads': currentReads,
      'readByUsers': readByUsers,
    };
  }

  factory SecretMessage.fromSyncJson(Map<String, dynamic> json) {
    return SecretMessage(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      ownerId: json['ownerId'] as String,
      ownerName: json['ownerName'] as String? ?? 'Аноним',
      ownerReputation: json['ownerReputation'] as int? ?? 0,
      secretType: SecretType.fromCode(json['secretType'] as String),
      title: json['title'] as String,
      content: _decrypt(json['encryptedContent'] as String), // Расшифровываем для конструктора
      unlockRadius: (json['unlockRadius'] as num?)?.toDouble() ?? 50,
      isOneTime: json['isOneTime'] as bool? ?? false,
      maxReads: json['maxReads'] as int? ?? 0,
      currentReads: json['currentReads'] as int? ?? 0,
      readByUsers: (json['readByUsers'] as List?)?.map((e) => e as String).toList(),
      status: MapObjectStatus.fromCode(json['status'] as String? ?? 'active'),
      confirms: json['confirms'] as int? ?? 0,
      denies: json['denies'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
    );
  }
}
