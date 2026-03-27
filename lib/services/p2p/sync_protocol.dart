import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/map_objects/map_objects.dart';
import 'map_object_storage.dart';
import 'p2p_connection.dart';

/// Стратегия разрешения конфликтов
enum ConflictResolution {
  lastWriteWins,    // Последняя запись побеждает
  serverWins,       // "Серверная" версия (более высокий version) побеждает
  merge,            // Попытка слияния
}

/// Статистика синхронизации
class SyncStats {
  int objectsSent = 0;
  int objectsReceived = 0;
  int objectsMerged = 0;
  int conflicts = 0;
  int errors = 0;

  void reset() {
    objectsSent = 0;
    objectsReceived = 0;
    objectsMerged = 0;
    conflicts = 0;
    errors = 0;
  }

  Map<String, int> toMap() => {
        'sent': objectsSent,
        'received': objectsReceived,
        'merged': objectsMerged,
        'conflicts': conflicts,
        'errors': errors,
      };
}

/// Протокол синхронизации объектов
/// Управляет синхронизацией между пирами с разрешением конфликтов
class SyncProtocol {
  final MapObjectStorage storage;
  final ConflictResolution conflictResolution;
  final Duration syncTimeout;

  final P2PConnectionManager _connectionManager;

  final StreamController<SyncStats> _syncCompleteController =
      StreamController<SyncStats>.broadcast();
  final StreamController<MapObject> _objectReceivedController =
      StreamController<MapObject>.broadcast();
  final StreamController<MapObject> _objectSentController =
      StreamController<MapObject>.broadcast();

  Stream<SyncStats> get syncCompleteStream => _syncCompleteController.stream;
  Stream<MapObject> get objectReceivedStream => _objectReceivedController.stream;
  Stream<MapObject> get objectSentStream => _objectSentController.stream;

  SyncProtocol({
    required this.storage,
    required P2PConnectionManager connectionManager,
    this.conflictResolution = ConflictResolution.lastWriteWins,
    this.syncTimeout = const Duration(seconds: 30),
  }) : _connectionManager = connectionManager {
    _init();
  }

  void _init() {
    // Слушаем входящие сообщения
    _connectionManager.messageStream.listen(_handleMessage);
  }

  /// Обработка входящего P2P сообщения
  Future<void> _handleMessage(P2PMessage message) async {
    switch (message.type) {
      case P2PMessageType.syncRequest:
        await _handleSyncRequest(message);
        break;

      case P2PMessageType.syncResponse:
        await _handleSyncResponse(message);
        break;

      case P2PMessageType.objectCreate:
      case P2PMessageType.objectUpdate:
        await _handleObjectMessage(message);
        break;

      case P2PMessageType.objectDelete:
        await _handleObjectDelete(message);
        break;

      default:
        break;
    }
  }

  /// Обработка запроса синхронизации
  Future<void> _handleSyncRequest(P2PMessage message) async {
    final payload = message.payload;
    if (payload == null) return;

    final sinceVersion = payload['sinceVersion'] as int? ?? 0;
    final requestedIds = (payload['objectIds'] as List?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    debugPrint('📥 Запрос синхронизации: sinceVersion=$sinceVersion, ids=${requestedIds.length}');

    // Получаем объекты для отправки
    final allObjects = await storage.getAllObjects();
    final objectsToSend = <Map<String, dynamic>>[];

    for (final obj in allObjects) {
      // Отправляем если версия новее или если объект в запрошенном списке
      if (obj.version > sinceVersion || requestedIds.contains(obj.id)) {
        objectsToSend.add(obj.toSyncJson());
      }
    }

    // Отправляем ответ
    final connection = _connectionManager.connections.values.firstWhere(
      (c) => c.isConnected,
      orElse: () => throw Exception('Нет активных соединений'),
    );

    connection.sendMessage(P2PMessage(
      type: P2PMessageType.syncResponse,
      payload: {
        'objects': objectsToSend,
        'totalCount': objectsToSend.length,
      },
    ));

    debugPrint('📤 Отправлено ${objectsToSend.length} объектов в ответ на sync');
  }

  /// Обработка ответа на синхронизацию
  Future<void> _handleSyncResponse(P2PMessage message) async {
    final payload = message.payload;
    if (payload == null) return;

    final objects = (payload['objects'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    debugPrint('📥 Получено ${objects.length} объектов в sync response');

    for (final objJson in objects) {
      await _processIncomingObject(objJson);
    }
  }

  /// Обработка сообщения о создании/обновлении объекта
  Future<void> _handleObjectMessage(P2PMessage message) async {
    final payload = message.payload;
    if (payload == null) return;

    debugPrint('📥 Получен объект: ${payload['type']} / ${payload['id']}');
    await _processIncomingObject(payload);
  }

  /// Обработка удаления объекта
  Future<void> _handleObjectDelete(P2PMessage message) async {
    final payload = message.payload;
    if (payload == null) return;

    final objectId = payload['id'] as String?;
    if (objectId == null) return;

    debugPrint('🗑️ Удаление объекта: $objectId');
    await storage.deleteObject(objectId);
  }

  /// Обработка входящего объекта
  Future<void> _processIncomingObject(Map<String, dynamic> objJson) async {
    try {
      final objectId = objJson['id'] as String;

      // Проверяем существующий объект
      final existing = await storage.getObject(objectId);

      if (existing != null) {
        // Разрешаем конфликт
        final resolved = _resolveConflict(existing, objJson);

        if (resolved == null) {
          // Локальная версия актуальнее - пропускаем
          return;
        }

        // Обновляем объект
        final updatedObject = MapObject.fromSyncJson(resolved);
        await storage.updateObject(updatedObject);
        _objectReceivedController.add(updatedObject);
      } else {
        // Новый объект - сохраняем
        final newObject = MapObject.fromSyncJson(objJson);
        await storage.saveObject(newObject);
        _objectReceivedController.add(newObject);
      }
    } catch (e) {
      debugPrint('❌ Ошибка обработки объекта: $e');
    }
  }

  /// Разрешение конфликта версий
  Map<String, dynamic>? _resolveConflict(
    MapObject local,
    Map<String, dynamic> incoming,
  ) {
    final incomingVersion = incoming['version'] as int? ?? 1;

    switch (conflictResolution) {
      case ConflictResolution.lastWriteWins:
        // Сравниваем версии
        if (incomingVersion > local.version) {
          return incoming;
        }
        return null; // Локальная версия актуальнее

      case ConflictResolution.serverWins:
        // Версия с большим номером побеждает
        if (incomingVersion >= local.version) {
          return incoming;
        }
        return null;

      case ConflictResolution.merge:
        // Пытаемся объединить (простая стратегия: берём максимальные значения)
        return _mergeObjects(local, incoming);
    }
  }

  /// Слияние объектов
  Map<String, dynamic> _mergeObjects(
    MapObject local,
    Map<String, dynamic> incoming,
  ) {
    final result = local.toSyncJson();
    final incomingMap = incoming;

    // Берём максимальную версию
    result['version'] = (local.version > (incomingMap['version'] as int? ?? 1))
        ? local.version
        : incomingMap['version'];

    // Берём максимальные счётчики
    result['confirms'] = (local.confirms > (incomingMap['confirms'] as int? ?? 0))
        ? local.confirms
        : incomingMap['confirms'];
    result['denies'] = (local.denies > (incomingMap['denies'] as int? ?? 0))
        ? local.denies
        : incomingMap['denies'];
    result['views'] = (local.views > (incomingMap['views'] as int? ?? 0))
        ? local.views
        : incomingMap['views'];

    // Для специфичных полей используем более новую версию
    // (это можно расширить для каждого типа объектов)

    return result;
  }

  /// Запросить синхронизацию у пиров
  Future<void> requestSync(String peerId) async {
    final connection = _connectionManager.getConnection(peerId);
    if (connection == null || !connection.isConnected) {
      debugPrint('⚠️ Нет соединения с пиром $peerId');
      return;
    }

    // Получаем локальные объекты для определения версии
    final localObjects = await storage.getAllObjects();
    final maxVersion = localObjects.isEmpty
        ? 0
        : localObjects.map((o) => o.version).reduce((a, b) => a > b ? a : b);

    connection.sendSyncRequest(
      localObjects.map((o) => o.id).toList(),
      maxVersion,
    );

    debugPrint('📤 Запрос синхронизации отправлен пиру $peerId');
  }

  /// Отправить объект всем пирам
  Future<void> broadcastObject(MapObject object, {bool isUpdate = false}) async {
    final message = P2PMessage(
      type: isUpdate ? P2PMessageType.objectUpdate : P2PMessageType.objectCreate,
      payload: object.toSyncJson(),
    );

    _connectionManager.broadcast(message);
    _objectSentController.add(object);

    debugPrint('📤 Объект ${object.id} отправлен всем пирам');
  }

  /// Отправить уведомление об удалении объекта
  void broadcastDelete(String objectId) {
    _connectionManager.broadcast(P2PMessage(
      type: P2PMessageType.objectDelete,
      payload: {'id': objectId},
    ));

    debugPrint('📤 Уведомление об удалении $objectId отправлено');
  }

  /// Полная двусторонняя синхронизация со всеми пирами
  Future<SyncStats> fullSync() async {
    final stats = SyncStats();

    try {
      final peers = _connectionManager.connectedPeers;
      if (peers.isEmpty) {
        debugPrint('⚠️ Нет подключенных пиров для синхронизации');
        return stats;
      }

      // Запрашиваем синхронизацию у всех пиров
      for (final peerId in peers) {
        await requestSync(peerId);
      }

      // Отправляем наши объекты всем пирам
      final localObjects = await storage.getAllObjects();
      for (final obj in localObjects) {
        broadcastObject(obj, isUpdate: true);
        stats.objectsSent++;
      }

      // Даём время на получение ответов
      await Future.delayed(const Duration(seconds: 2));

      _syncCompleteController.add(stats);
    } catch (e) {
      debugPrint('❌ Ошибка синхронизации: $e');
      stats.errors++;
    }

    return stats;
  }

  void dispose() {
    _syncCompleteController.close();
    _objectReceivedController.close();
    _objectSentController.close();
  }
}
