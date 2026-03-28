import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/map_objects/map_objects.dart';

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
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
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

    await db.execute('CREATE INDEX idx_geohash ON map_objects(geohash)');
    await db.execute('CREATE INDEX idx_type ON map_objects(type)');
    await db.execute('CREATE INDEX idx_status ON map_objects(status)');
    await db.execute('CREATE INDEX idx_owner ON map_objects(owner_id)');

    await _createV2Tables(db);
  }

  /// Создать таблицы версии 2 (фото, интересы, сообщения)
  Future<void> _createV2Tables(Database db) async {
    // Таблица фото
    await db.execute('''
      CREATE TABLE IF NOT EXISTS photos (
        id TEXT PRIMARY KEY,
        object_id TEXT,
        webp_data BLOB NOT NULL,
        width INTEGER,
        height INTEGER,
        size_bytes INTEGER,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_photo_object ON photos(object_id)');

    // Таблица интересов
    await db.execute('''
      CREATE TABLE IF NOT EXISTS interests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        contact_request_sent INTEGER DEFAULT 0,
        contact_approved INTEGER DEFAULT 0,
        UNIQUE(note_id, user_id)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_interest_note ON interests(note_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_interest_user ON interests(user_id)');

    // Таблица P2P сообщений
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        from_user_id TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        delivered INTEGER DEFAULT 0,
        read INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_from ON messages(from_user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_to ON messages(to_user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_chat ON messages(from_user_id, to_user_id)');

    // Таблица профилей контактов
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contact_profiles (
        user_id TEXT PRIMARY KEY,
        about TEXT,
        vk_link TEXT,
        max_link TEXT,
        visibility TEXT DEFAULT 'after_approval',
        accept_p2p_messages INTEGER DEFAULT 1
      )
    ''');
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

  /// Очистить все объекты
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('map_objects');
    _notifyUpdate();
  }

  void _notifyUpdate() {
    getAllObjects().then((objects) {
      _objectsController.add(objects);
    });
  }

  // ==================== PHOTO METHODS ====================

  /// Сохранить фото
  Future<void> savePhoto({
    required String id,
    String? objectId,
    required List<int> webpData,
    int? width,
    int? height,
    int? sizeBytes,
    String status = 'pending',
  }) async {
    final db = await database;
    await db.insert(
      'photos',
      {
        'id': id,
        'object_id': objectId,
        'webp_data': webpData,
        'width': width,
        'height': height,
        'size_bytes': sizeBytes,
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Получить фото по ID
  Future<Map<String, dynamic>?> getPhoto(String id) async {
    final db = await database;
    final results = await db.query(
      'photos',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  /// Получить все фото объекта
  Future<List<Map<String, dynamic>>> getPhotosForObject(String objectId) async {
    final db = await database;
    return await db.query(
      'photos',
      where: 'object_id = ?',
      whereArgs: [objectId],
    );
  }

  /// Обновить статус фото
  Future<void> updatePhotoStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'photos',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Удалить фото
  Future<void> deletePhoto(String id) async {
    final db = await database;
    await db.delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== INTEREST METHODS ====================

  /// Добавить интерес
  Future<void> addInterest({
    required String noteId,
    required String userId,
    bool contactRequestSent = false,
    bool contactApproved = false,
  }) async {
    final db = await database;
    await db.insert(
      'interests',
      {
        'note_id': noteId,
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'contact_request_sent': contactRequestSent ? 1 : 0,
        'contact_approved': contactApproved ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Удалить интерес
  Future<void> removeInterest(String noteId, String userId) async {
    final db = await database;
    await db.delete(
      'interests',
      where: 'note_id = ? AND user_id = ?',
      whereArgs: [noteId, userId],
    );
  }

  /// Получить интересы к заметке
  Future<List<Map<String, dynamic>>> getInterestsForNote(String noteId) async {
    final db = await database;
    return await db.query(
      'interests',
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
  }

  /// Проверить, есть ли интерес от пользователя
  Future<bool> hasInterest(String noteId, String userId) async {
    final db = await database;
    final results = await db.query(
      'interests',
      where: 'note_id = ? AND user_id = ?',
      whereArgs: [noteId, userId],
    );
    return results.isNotEmpty;
  }

  /// Одобрить контакт
  Future<void> approveContact(String noteId, String userId) async {
    final db = await database;
    await db.update(
      'interests',
      {'contact_approved': 1},
      where: 'note_id = ? AND user_id = ?',
      whereArgs: [noteId, userId],
    );
  }

  // ==================== MESSAGE METHODS ====================

  /// Сохранить сообщение
  Future<void> saveMessage(Map<String, dynamic> message) async {
    final db = await database;
    await db.insert(
      'messages',
      {
        'id': message['id'],
        'from_user_id': message['fromUserId'],
        'to_user_id': message['toUserId'],
        'content': message['content'],
        'timestamp': message['timestamp'],
        'delivered': message['delivered'] == true ? 1 : 0,
        'read': message['read'] == true ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Получить сообщения чата
  Future<List<Map<String, dynamic>>> getChatMessages(
    String userId1,
    String userId2,
  ) async {
    final db = await database;
    return await db.query(
      'messages',
      where: '(from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?)',
      whereArgs: [userId1, userId2, userId2, userId1],
      orderBy: 'timestamp ASC',
    );
  }

  /// Получить непрочитанные сообщения
  Future<List<Map<String, dynamic>>> getUnreadMessages(String userId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'to_user_id = ? AND read = 0',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
  }

  /// Отметить сообщения как прочитанные
  Future<void> markMessagesAsRead(String fromUserId, String toUserId) async {
    final db = await database;
    await db.update(
      'messages',
      {'read': 1},
      where: 'from_user_id = ? AND to_user_id = ? AND read = 0',
      whereArgs: [fromUserId, toUserId],
    );
  }

  /// Получить список чатов
  Future<List<Map<String, dynamic>>> getChatList(String userId) async {
    final db = await database;
    
    // Получаем уникальные собеседников
    final results = await db.rawQuery('''
      SELECT 
        CASE 
          WHEN from_user_id = ? THEN to_user_id 
          ELSE from_user_id 
        END as other_user_id,
        MAX(timestamp) as last_message_time
      FROM messages
      WHERE from_user_id = ? OR to_user_id = ?
      GROUP BY other_user_id
      ORDER BY last_message_time DESC
    ''', [userId, userId, userId]);
    
    return results;
  }

  // ==================== CONTACT PROFILE METHODS ====================

  /// Сохранить профиль контакта
  Future<void> saveContactProfile(Map<String, dynamic> profile) async {
    final db = await database;
    await db.insert(
      'contact_profiles',
      {
        'user_id': profile['userId'],
        'about': profile['about'],
        'vk_link': profile['vkLink'],
        'max_link': profile['maxLink'],
        'visibility': profile['visibility'],
        'accept_p2p_messages': profile['acceptP2PMessages'] == true ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Получить профиль контакта
  Future<Map<String, dynamic>?> getContactProfile(String userId) async {
    final db = await database;
    final results = await db.query(
      'contact_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  void dispose() {
    _objectsController.close();
  }
}
