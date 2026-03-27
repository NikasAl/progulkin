import 'package:latlong2/latlong.dart';
import '../models/map_objects/map_objects.dart';
import '../providers/map_object_provider.dart';

/// Результат проверки возможности действия
class ActionCheckResult {
  final bool canPerform;
  final String? hint;
  final String? actionLabel;

  const ActionCheckResult({
    required this.canPerform,
    this.hint,
    this.actionLabel,
  });

  const ActionCheckResult.allowed({String? label})
      : canPerform = true,
        hint = null,
        actionLabel = label;

  const ActionCheckResult.denied(this.hint)
      : canPerform = false,
        actionLabel = null;
}

/// Результат выполнения действия
class ActionResult {
  final bool success;
  final String? message;
  final int? points;
  final String? error;
  final String? secretContent;
  final String? secretTitle;

  const ActionResult({
    required this.success,
    this.message,
    this.points,
    this.error,
    this.secretContent,
    this.secretTitle,
  });

  const ActionResult.success({this.message, this.points})
      : success = true,
        error = null,
        secretContent = null,
        secretTitle = null;

  const ActionResult.error(this.error)
      : success = false,
        message = null,
        points = null,
        secretContent = null,
        secretTitle = null;

  const ActionResult.secretRead(this.secretTitle, this.secretContent)
      : success = true,
        message = null,
        points = null,
        error = null;
}

/// Сервис для действий с объектами на карте
///
/// Выносит бизнес-логику из UI-слоя, обеспечивая:
/// - Проверку условий для действий
/// - Выполнение действий через провайдер
/// - Унифицированный интерфейс для всех типов объектов
class ObjectActionService {
  final MapObjectProvider _objectProvider;

  /// Радиус действия для уборки мусора (в метрах)
  final double cleaningRadius;

  /// Радиус действия для поимки существ (в метрах)
  final double catchingRadius;

  ObjectActionService({
    required MapObjectProvider objectProvider,
    this.cleaningRadius = 100.0,
    this.catchingRadius = 50.0,
  }) : _objectProvider = objectProvider;

  /// Проверить возможность действия с объектом
  ActionCheckResult canPerformAction(
    MapObject object, {
    required bool isWalking,
    required LatLng? userLocation,
    required String userId,
  }) {
    switch (object.type) {
      case MapObjectType.trashMonster:
        return _checkTrashMonsterAction(
          object as TrashMonster,
          isWalking: isWalking,
          userLocation: userLocation,
        );

      case MapObjectType.secretMessage:
        return _checkSecretMessageAction(
          object as SecretMessage,
          isWalking: isWalking,
          userLocation: userLocation,
          userId: userId,
        );

      case MapObjectType.creature:
        return _checkCreatureAction(
          object as Creature,
          isWalking: isWalking,
          userLocation: userLocation,
        );

      default:
        return const ActionCheckResult.denied('Неизвестный тип объекта');
    }
  }

  /// Выполнить действие с объектом
  Future<ActionResult> performAction(
    MapObject object, {
    required String userId,
    required String userName,
  }) async {
    switch (object.type) {
      case MapObjectType.trashMonster:
        return await _cleanTrashMonster(object as TrashMonster, userId);

      case MapObjectType.secretMessage:
        return await _readSecretMessage(object as SecretMessage, userId);

      case MapObjectType.creature:
        return await _catchCreature(
          object as Creature,
          userId,
          userName,
        );

      default:
        return const ActionResult.error('Неизвестный тип объекта');
    }
  }

  // === Проверки действий ===

  ActionCheckResult _checkTrashMonsterAction(
    TrashMonster monster, {
    required bool isWalking,
    required LatLng? userLocation,
  }) {
    if (monster.isCleaned) {
      return const ActionCheckResult.denied('Уже убрано');
    }

    if (!isWalking) {
      return const ActionCheckResult.denied('💼 Начните прогулку, чтобы отметить как убранное');
    }

    if (userLocation == null) {
      return const ActionCheckResult.denied('📍 Определяем ваше местоположение...');
    }

    final distance = _calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      monster.latitude,
      monster.longitude,
    );

    if (distance > cleaningRadius) {
      return ActionCheckResult.denied(
        '📍 Подойдите ближе (${distance.toInt()} м до цели)',
      );
    }

    return const ActionCheckResult.allowed(label: 'Убрано!');
  }

  ActionCheckResult _checkSecretMessageAction(
    SecretMessage secret, {
    required bool isWalking,
    required LatLng? userLocation,
    required String userId,
  }) {
    if (secret.isReadByUser(userId)) {
      return const ActionCheckResult.denied('✅ Вы уже прочитали это сообщение');
    }

    if (!isWalking) {
      return const ActionCheckResult.denied('💼 Начните прогулку, чтобы прочитать сообщение');
    }

    if (userLocation == null) {
      return const ActionCheckResult.denied('📍 Определяем ваше местоположение...');
    }

    final distance = _calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      secret.latitude,
      secret.longitude,
    );

    if (distance > secret.unlockRadius) {
      return ActionCheckResult.denied(
        '📍 Подойдите ближе (${distance.toInt()} м до разблокировки)',
      );
    }

    return const ActionCheckResult.allowed(label: 'Прочитать');
  }

  ActionCheckResult _checkCreatureAction(
    Creature creature, {
    required bool isWalking,
    required LatLng? userLocation,
  }) {
    if (!creature.isWild) {
      return ActionCheckResult.denied('🏠 Уже приручено ${creature.ownerName}');
    }

    if (!isWalking) {
      return const ActionCheckResult.denied('💼 Начните прогулку, чтобы поймать');
    }

    if (userLocation == null) {
      return const ActionCheckResult.denied('📍 Определяем ваше местоположение...');
    }

    final distance = _calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      creature.latitude,
      creature.longitude,
    );

    if (distance > catchingRadius) {
      return ActionCheckResult.denied(
        '📍 Подойдите ближе (${distance.toInt()} м до цели)',
      );
    }

    return const ActionCheckResult.allowed(label: 'Поймать!');
  }

  // === Выполнение действий ===

  Future<ActionResult> _cleanTrashMonster(
    TrashMonster monster,
    String userId,
  ) async {
    try {
      await _objectProvider.cleanTrashMonster(monster.id, userId);
      return ActionResult.success(
        message: 'Отлично!',
        points: monster.cleaningPoints,
      );
    } catch (e) {
      return ActionResult.error('Не удалось отметить как убранное: $e');
    }
  }

  Future<ActionResult> _readSecretMessage(
    SecretMessage secret,
    String userId,
  ) async {
    try {
      final content = await _objectProvider.readSecretMessage(secret.id, userId);
      if (content == null) {
        return const ActionResult.error('Не удалось прочитать сообщение');
      }
      return ActionResult.secretRead(secret.title, content);
    } catch (e) {
      return ActionResult.error('Ошибка чтения: $e');
    }
  }

  Future<ActionResult> _catchCreature(
    Creature creature,
    String userId,
    String userName,
  ) async {
    try {
      await _objectProvider.catchCreature(creature.id, userId, userName);
      return ActionResult.success(
        message: '${creature.creatureType.name} пойман!',
      );
    } catch (e) {
      return ActionResult.error('Не удалось поймать: $e');
    }
  }

  // === Утилиты ===

  /// Расчёт расстояния между двумя точками (в метрах)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = 0.5 -
        0.5 * _cos(dLat) +
        0.5 * _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            (1 - _cos(dLon));

    return earthRadius * 2 * _asin(_sqrt(a));
  }

  double _toRadians(double degree) => degree * 0.017453292519943295;
  double _cos(double x) => x.isFinite ? (1 - x * x / 2 + x * x * x * x / 24) : double.nan;
  double _asin(double x) => x.isFinite && x.abs() <= 1 ? (x * (1 + x * x / 6)) : double.nan;
  double _sqrt(double x) => x >= 0 ? x * 0.5 + 0.5 * x / (x * 0.5) : double.nan;
}
