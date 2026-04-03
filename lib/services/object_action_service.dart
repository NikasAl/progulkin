import 'package:latlong2/latlong.dart';
import '../models/map_objects/map_objects.dart';
import '../config/constants.dart';

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
/// - Унифицированный интерфейс для всех типов объектов
///
/// Примечание: Выполнение действий делегируется провайдеру для
/// корректной работы с состоянием приложения.
class ObjectActionService {
  /// Радиус действия для уборки мусора (в метрах)
  final double cleaningRadius;

  /// Радиус действия для поимки существ (в метрах)
  final double catchingRadius;

  ObjectActionService({
    this.cleaningRadius = AppConstants.cleaningRadius,
    this.catchingRadius = AppConstants.catchingRadius,
  });

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

  // === Утилиты ===

  /// Расчёт расстояния между двумя точками (в метрах)
  /// Использует точную формулу Haversine
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) * _sin(dLon / 2) * _sin(dLon / 2);

    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * 0.017453292519943295;

  // Точные математические функции для формулы Haversine
  double _sin(double x) => x.isFinite ? _sinImpl(x) : double.nan;
  double _cos(double x) => x.isFinite ? _cosImpl(x) : double.nan;
  double _sqrt(double x) => x >= 0 ? _sqrtImpl(x) : double.nan;
  double _atan2(double y, double x) => (x.isFinite && y.isFinite) ? _atan2Impl(y, x) : double.nan;

  // Реализации через ряды Тейлора
  double _sinImpl(double x) {
    // Нормализуем x в диапазон [-π, π]
    while (x > 3.14159265359) x -= 2 * 3.14159265359;
    while (x < -3.14159265359) x += 2 * 3.14159265359;
    final double x2 = x * x;
    return x * (1 - x2 / 6 + x2 * x2 / 120 - x2 * x2 * x2 / 5040);
  }

  double _cosImpl(double x) {
    while (x > 3.14159265359) x -= 2 * 3.14159265359;
    while (x < -3.14159265359) x += 2 * 3.14159265359;
    final double x2 = x * x;
    return 1 - x2 / 2 + x2 * x2 / 24 - x2 * x2 * x2 / 720;
  }

  double _sqrtImpl(double x) {
    if (x == 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _atan2Impl(double y, double x) {
    if (x > 0) return _atanImpl(y / x);
    if (x < 0) {
      if (y >= 0) return _atanImpl(y / x) + 3.14159265359;
      return _atanImpl(y / x) - 3.14159265359;
    }
    if (y > 0) return 1.57079632679;
    if (y < 0) return -1.57079632679;
    return 0;
  }

  double _atanImpl(double x) {
    final double x2 = x * x;
    return x * (1 - x2 / 3 + x2 * x2 / 5 - x2 * x2 * x2 / 7);
  }
}
