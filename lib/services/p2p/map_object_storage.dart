import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/map_objects/map_objects.dart';

/// Локальное хранилище объектов карты
class MapObjectStorage {
  static final MapObjectStorage _instance = MapObjectStorage._internal();
  factory MapObjectStorage() => _instance;
  MapObjectStorage._internal();

  Database? _database;
  final StreamController<List<MapObject>> _objectsController =
      StreamController<List<MapObject>>.broadcast();

  Stream<List<MapObject>> get objectsStream => _objectsController.stream;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'map_objects.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Таблица объектов
        await db.execute('''
          CREATE TABLE map_objects (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            owner_id TEXT NOT NULL,
            owner_name TEXT,
            owner_reputation INTEGER DEFAULT 0,
            data TEXT NOT NULL,
            status TEXT NOT NULL,
            confirms INTEGER DEFAULT 0,
            denies INTEGER DEFAULT 0,
            views INTEGER DEFAULT 0,
            version INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            geohash TEXT NOT NULL,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        // Индексы для быстрого поиска
        await db.execute('CREATE INDEX idx_geohash ON map_objects(geohash)');
        await db.execute('CREATE INDEX idx_type ON map_objects(type)');
        await db.execute('CREATE INDEX idx_status ON map_objects(status)');
        await db.execute('CREATE INDEX idx_owner ON map_objects(owner_id)');
      },
    );
  }

  /// Сохранить объект
  Future<void> saveObject(MapObject object) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'map_objects',
      {
        'id': object.id,
        'type': object.type.code,
        'latitude': object.latitude,
        'longitude': object.longitude,
        'owner_id': object.ownerId,
        'owner_name': object.ownerName,
        'owner_reputation': object.ownerReputation,
        'data': jsonEncode(object.toSyncJson()),
        'status': object.status.code,
        'confirms': object.confirms,
        'denies': object.denies,
        'views': object.views,
        'version': object.version,
        'created_at': object.createdAt.toIso8601String(),
        'updated_at': now,
        'geohash': object.geohash,
        'is_synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _notifyUpdate();
  }

  /// Получить объект по ID
  Future<MapObject?> getObject(String id) async {
    final db = await database;
    final results = await db.query(
      'map_objects',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final data = jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
    return MapObject.fromSyncJson(data);
  }

  /// Получить все объекты
  Future<List<MapObject>> getAllObjects() async {
    final db = await database;
    final results = await db.query('map_objects');

    return results.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return MapObject.fromSyncJson(data);
    }).toList();
  }

  /// Получить объекты по типу
  Future<List<MapObject>> getObjectsByType(MapObjectType type) async {
    final db = await database;
    final results = await db.query(
      'map_objects',
      where: 'type = ?',
      whereArgs: [type.code],
    );

    return results.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return MapObject.fromSyncJson(data);
    }).toList();
  }

  /// Получить объекты в зоне (по geohash префиксу)
  Future<List<MapObject>> getObjectsInZone(String geohashPrefix) async {
    final db = await database;
    final results = await db.query(
      'map_objects',
      where: 'geohash LIKE ?',
      whereArgs: ['$geohashPrefix%'],
    );

    return results.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return MapObject.fromSyncJson(data);
    }).toList();
  }

  /// Получить объекты в радиусе
  Future<List<MapObject>> getObjectsInRadius(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    final all = await getAllObjects();
    return all.where((obj) {
      final distance = calculateDistance(lat, lng, obj.latitude, obj.longitude);
      return distance <= radiusMeters;
    }).toList();
  }

  /// Получить активные объекты (не убранные, не скрытые)
  Future<List<MapObject>> getActiveObjects() async {
    final db = await database;
    final results = await db.query(
      'map_objects',
      where: 'status IN (?, ?, ?',
      whereArgs: ['active', 'confirmed', 'cleaned'],
    );

    return results.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return MapObject.fromSyncJson(data);
    }).toList();
  }

  /// Обновить объект
  Future<void> updateObject(MapObject object) async {
    await saveObject(object);
  }

  /// Удалить объект
  Future<void> deleteObject(String id) async {
    final db = await database;
    await db.delete(
      'map_objects',
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyUpdate();
  }

  /// Удалить объекты пользователя
  Future<void> deleteObjectsByOwner(String ownerId) async {
    final db = await database;
    await db.delete(
      'map_objects',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
    );
    _notifyUpdate();
  }

  /// Очистить все объекты
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('map_objects');
    _notifyUpdate();
  }

  /// Получить статистику
  Future<Map<String, int>> getStats() async {
    final db = await database;

    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM map_objects'),
    ) ?? 0;

    final byType = <String, int>{};
    for (final type in MapObjectType.values) {
      final count = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM map_objects WHERE type = ?',
          [type.code],
        ),
      ) ?? 0;
      byType[type.code] = count;
    }

    return {
      'total': total,
      ...byType,
    };
  }

  /// Массовая вставка при синхронизации
  Future<void> bulkInsert(List<MapObject> objects) async {
    final db = await database;
    final batch = db.batch();

    for (final obj in objects) {
      batch.insert(
        'map_objects',
        {
          'id': obj.id,
          'type': obj.type.code,
          'latitude': obj.latitude,
          'longitude': obj.longitude,
          'owner_id': obj.ownerId,
          'owner_name': obj.ownerName,
          'owner_reputation': obj.ownerReputation,
          'data': jsonEncode(obj.toSyncJson()),
          'status': obj.status.code,
          'confirms': obj.confirms,
          'denies': obj.denies,
          'views': obj.views,
          'version': obj.version,
          'created_at': obj.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'geohash': obj.geohash,
          'is_synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    _notifyUpdate();
  }

  /// Получить несинхронизированные объекты
  Future<List<MapObject>> getUnsyncedObjects() async {
    final db = await database;
    final results = await db.query(
      'map_objects',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    return results.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return MapObject.fromSyncJson(data);
    }).toList();
  }

  /// Отметить как синхронизированный
  Future<void> markAsSynced(String id) async {
    final db = await database;
    await db.update(
      'map_objects',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  void _notifyUpdate() {
    getAllObjects().then((objects) {
      _objectsController.add(objects);
    });
  }

  void dispose() {
    _objectsController.close();
  }
}
