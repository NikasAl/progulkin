import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/map_objects/map_objects.dart';
import '../models/contact_profile.dart';
import '../services/p2p/p2p.dart';
import '../services/map_object_export_service.dart';

/// Провайдер для управления объектами на карте
class MapObjectProvider extends ChangeNotifier {
  final MapObjectStorage _storage = MapObjectStorage();
  final P2PService _p2pService = P2PService();
  final MapObjectExportService _exportService = MapObjectExportService();
  final Uuid _uuid = const Uuid();

  /// Доступ к хранилищу для прямого использования
  MapObjectStorage get storage => _storage;

  List<MapObject> _objects = [];
  List<MapObject> _nearbyObjects = [];
  MapObjectType? _selectedType;
  bool _isLoading = false;
  bool _p2pEnabled = true;
  String? _error;

  // Фильтры
  final Set<MapObjectType> _enabledTypes = Set.from(MapObjectType.values);
  bool _showCleaned = false;
  int _minReputation = 0;

  // Текущая позиция пользователя
  double? _userLat;
  double? _userLng;

  // Подписки
  StreamSubscription? _objectsSubscription;
  StreamSubscription? _newObjectSubscription;
  StreamSubscription? _syncSubscription;

  // Геттеры
  List<MapObject> get objects => _filterObjects(_objects);
  List<MapObject> get nearbyObjects => _filterObjects(_nearbyObjects);
  List<MapObject> get allObjects => _objects;
  MapObjectType? get selectedType => _selectedType;
  bool get isLoading => _isLoading;
  bool get p2pEnabled => _p2pEnabled;
  String? get error => _error;
  Set<MapObjectType> get enabledTypes => Set.unmodifiable(_enabledTypes);
  bool get showCleaned => _showCleaned;
  int get minReputation => _minReputation;
  bool get isP2PRunning => _p2pService.isRunning;

  /// Количество объектов по типам
  Map<MapObjectType, int> get objectCounts {
    final counts = <MapObjectType, int>{};
    for (final type in MapObjectType.values) {
      counts[type] = _objects.where((o) => o.type == type).length;
    }
    return counts;
  }

  /// Статистика
  Map<String, int> get stats {
    int total = _objects.length;
    int trashMonsters = _objects.where((o) => o.type == MapObjectType.trashMonster).length;
    int cleaned = _objects.where((o) => o.type == MapObjectType.trashMonster)
        .where((o) => (o as TrashMonster).isCleaned).length;
    int secrets = _objects.where((o) => o.type == MapObjectType.secretMessage).length;
    int creatures = _objects.where((o) => o.type == MapObjectType.creature).length;

    return {
      'total': total,
      'trashMonsters': trashMonsters,
      'cleaned': cleaned,
      'secrets': secrets,
      'creatures': creatures,
    };
  }

  /// Инициализация
  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Загружаем объекты из локального хранилища
      _objects = await _storage.getAllObjects();

      // Подписываемся на новые объекты от P2P
      _newObjectSubscription = _p2pService.newObjectStream.listen((MapObject object) {
        _onNewObjectReceived(object);
      });

      // Подписываемся на результаты синхронизации
      _syncSubscription = _p2pService.syncStream.listen((result) {
        if (result.hasChanges) {
          debugPrint('🔄 Синхронизация: получено=${result.objectsReceived}, отправлено=${result.objectsSent}');
          _reloadObjects();
        }
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('❌ Ошибка инициализации MapObjectProvider: $e');
      notifyListeners();
    }
  }

  /// Запуск P2P сервиса
  Future<void> startP2P({
    required String signalingServer,
    required int signalingPort,
    required String deviceId,
  }) async {
    if (!_p2pEnabled || _userLat == null || _userLng == null) {
      debugPrint('⚠️ P2P не запущен: enabled=$_p2pEnabled, hasLocation=${_userLat != null}');
      return;
    }

    try {
      final zone = MapObject.encodeGeohash(_userLat!, _userLng!, 6);

      final config = P2PConfig(
        signalingServer: signalingServer,
        signalingPort: signalingPort,
        zone: zone,
        deviceId: deviceId,
      );

      await _p2pService.start(config);
      debugPrint('✅ P2P запущен в зоне $zone');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Ошибка запуска P2P: $e');
      _error = 'Ошибка P2P: $e';
      notifyListeners();
    }
  }

  /// Остановка P2P сервиса
  Future<void> stopP2P() async {
    await _p2pService.stop();
    debugPrint('🛑 P2P остановлен');
    notifyListeners();
  }

  /// Обновление позиции пользователя
  void updateUserPosition(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    _updateNearbyObjects();
    notifyListeners();
  }

  /// Создание мусорного монстра
  Future<TrashMonster> createTrashMonster({
    required double latitude,
    required double longitude,
    required String ownerId,
    String ownerName = 'Аноним',
    int ownerReputation = 0,
    required TrashType trashType,
    required TrashQuantity quantity,
    String description = '',
    List<String>? photoIds,
  }) async {
    final monster = TrashMonster.autoClass(
      id: _uuid.v4(),
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerReputation: ownerReputation,
      trashType: trashType,
      quantity: quantity,
      description: description,
      photoIds: photoIds,
    );

    await _saveAndBroadcast(monster);
    return monster;
  }

  /// Создание секретного сообщения
  Future<SecretMessage> createSecretMessage({
    required double latitude,
    required double longitude,
    required String ownerId,
    String ownerName = 'Аноним',
    int ownerReputation = 0,
    required SecretType secretType,
    required String title,
    required String content,
    double unlockRadius = 50,
    bool isOneTime = false,
    int maxReads = 0,
  }) async {
    final message = SecretMessage(
      id: _uuid.v4(),
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerReputation: ownerReputation,
      secretType: secretType,
      title: title,
      content: content,
      unlockRadius: unlockRadius,
      isOneTime: isOneTime,
      maxReads: maxReads,
    );

    await _saveAndBroadcast(message);
    return message;
  }

  /// Создание существа
  Future<Creature> spawnCreature({
    required double latitude,
    required double longitude,
    required CreatureType creatureType,
    required CreatureRarity rarity,
    required CreatureHabitat habitat,
    int lifetimeMinutes = 60,
  }) async {
    final creature = Creature.spawnWild(
      id: _uuid.v4(),
      latitude: latitude,
      longitude: longitude,
      creatureType: creatureType,
      rarity: rarity,
      habitat: habitat,
      lifetimeMinutes: lifetimeMinutes,
    );

    await _saveAndBroadcast(creature);
    return creature;
  }

  /// Создание заметки об интересном месте
  Future<InterestNote> createInterestNote({
    required double latitude,
    required double longitude,
    required String ownerId,
    String ownerName = 'Аноним',
    int ownerReputation = 0,
    required InterestCategory category,
    required String title,
    String description = '',
    List<String> photoIds = const [],
    bool contactVisible = false,
  }) async {
    final note = InterestNote(
      id: _uuid.v4(),
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerReputation: ownerReputation,
      category: category,
      title: title,
      description: description,
      photoIds: photoIds,
      contactVisible: contactVisible,
    );

    await _saveAndBroadcast(note);
    return note;
  }

  /// Создание напоминалки
  Future<ReminderCharacter> createReminderCharacter({
    required double latitude,
    required double longitude,
    required String ownerId,
    String ownerName = 'Аноним',
    int ownerReputation = 0,
    required ReminderCharacterType characterType,
    required String reminderText,
    double triggerRadius = 50,
  }) async {
    final reminder = ReminderCharacter(
      id: _uuid.v4(),
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerReputation: ownerReputation,
      characterType: characterType,
      reminderText: reminderText,
      triggerRadius: triggerRadius,
    );

    await _saveAndBroadcast(reminder);
    return reminder;
  }

  /// Добавить "Интересно" к заметке
  Future<void> addInterestToNote(String noteId, String userId) async {
    await _storage.addInterest(noteId: noteId, userId: userId);
    
    final obj = await _storage.getObject(noteId);
    if (obj == null || obj is! InterestNote) return;

    final updated = obj.addInterest(userId);
    await _storage.updateObject(updated);
    await _broadcastUpdate(updated);
    
    // Обновляем локальный список
    final index = _objects.indexWhere((o) => o.id == noteId);
    if (index >= 0) {
      _objects[index] = updated;
    }
    
    notifyListeners();
  }

  /// Убрать "Интересно" с заметки
  Future<void> removeInterestFromNote(String noteId, String userId) async {
    await _storage.removeInterest(noteId, userId);
    
    final obj = await _storage.getObject(noteId);
    if (obj == null || obj is! InterestNote) return;

    final updated = obj.removeInterest(userId);
    await _storage.updateObject(updated);
    await _broadcastUpdate(updated);
    
    // Обновляем локальный список
    final index = _objects.indexWhere((o) => o.id == noteId);
    if (index >= 0) {
      _objects[index] = updated;
    }
    
    notifyListeners();
  }

  /// Получить список пользователей, отметивших "Интересно"
  Future<List<NoteInterest>> getInterestsForNote(String noteId) async {
    final results = await _storage.getInterestsForNote(noteId);
    return results.map((json) => NoteInterest.fromJson(json)).toList();
  }

  /// Проверил ли пользователь "Интересно" на заметке
  Future<bool> hasInterest(String noteId, String userId) async {
    final interests = await getInterestsForNote(noteId);
    return interests.any((i) => i.userId == userId);
  }

  /// Запросить контакт у автора заметки
  Future<void> requestContact(String noteId, String userId) async {
    await _storage.addInterest(
      noteId: noteId,
      userId: userId,
      contactRequestSent: true,
    );
    
    // TODO: Отправить P2P уведомление автору
  }

  /// Одобрить запрос на контакт
  Future<void> approveContactRequest(String noteId, String userId) async {
    await _storage.addInterest(
      noteId: noteId,
      userId: userId,
      contactRequestSent: true,
      contactApproved: true,
    );
  }

  /// Подтвердить объект
  Future<void> confirmObject(String objectId) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null) return;

    obj.confirms++;
    obj.incrementVersion();

    await _storage.updateObject(obj);
    await _broadcastUpdate(obj);
    notifyListeners();
  }

  /// Опровергнуть объект
  Future<void> denyObject(String objectId) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null) return;

    obj.denies++;
    obj.incrementVersion();

    // Автоскрытие при большом количестве жалоб
    if (obj.shouldBeHidden) {
      obj.status = MapObjectStatus.hidden;
    }

    await _storage.updateObject(obj);
    await _broadcastUpdate(obj);
    notifyListeners();
  }

  /// Отметить монстра как убранного
  Future<void> cleanTrashMonster(String objectId, String userId) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null || obj is! TrashMonster) return;

    final cleaned = obj.markAsCleaned(userId);
    await _storage.updateObject(cleaned);
    await _broadcastUpdate(cleaned);
    notifyListeners();
  }

  /// Поймать существо
  Future<void> catchCreature(String objectId, String userId, String userName) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null || obj is! Creature) return;

    final caught = obj.catchCreature(userId, userName);
    await _storage.updateObject(caught);
    await _broadcastUpdate(caught);
    notifyListeners();
  }

  /// Прочитать секретное сообщение
  Future<String?> readSecretMessage(String objectId, String userId) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null || obj is! SecretMessage) return null;
    if (_userLat == null || _userLng == null) return null;

    final content = obj.decryptContent(userId, _userLat!, _userLng!);
    if (content != null) {
      final updated = obj.markAsRead(userId);
      await _storage.updateObject(updated);
      await _broadcastUpdate(updated);
      notifyListeners();
    }

    return content;
  }

  /// Удалить объект (только свои)
  Future<void> deleteObject(String objectId, String userId) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null) return;

    if (obj.ownerId != userId) {
      throw Exception('Можно удалить только свои объекты');
    }

    await _storage.deleteObject(objectId);
    _objects.removeWhere((o) => o.id == objectId);
    notifyListeners();
  }

  /// Получить объект по ID
  Future<MapObject?> getObject(String id) async {
    return await _storage.getObject(id);
  }

  /// Получить объекты в радиусе
  Future<List<MapObject>> getObjectsInRadius(double lat, double lng, double radiusMeters) async {
    return await _storage.getObjectsInRadius(lat, lng, radiusMeters);
  }

  /// Включить/выключить тип объектов
  void toggleObjectType(MapObjectType type) {
    if (_enabledTypes.contains(type)) {
      _enabledTypes.remove(type);
    } else {
      _enabledTypes.add(type);
    }
    notifyListeners();
  }

  /// Установить фильтр по типу
  void setSelectedType(MapObjectType? type) {
    _selectedType = type;
    notifyListeners();
  }

  /// Показывать убранные монстры
  void setShowCleaned(bool show) {
    _showCleaned = show;
    notifyListeners();
  }

  /// Минимальная репутация
  void setMinReputation(int reputation) {
    _minReputation = reputation;
    notifyListeners();
  }

  /// Включить/выключить P2P
  void setP2PEnabled(bool enabled) {
    _p2pEnabled = enabled;
    if (!enabled && _p2pService.isRunning) {
      stopP2P();
    }
    notifyListeners();
  }

  /// Принудительная синхронизация
  Future<void> forceSync() async {
    await _p2pService.forceSync();
  }

  /// Очистить все объекты
  Future<void> clearAll() async {
    await _storage.clearAll();
    _objects = [];
    _nearbyObjects = [];
    notifyListeners();
  }

  /// Перезагрузить объекты из хранилища (после импорта)
  Future<void> reload() async {
    await _reloadObjects();
  }

  // ==================== Экспорт/Импорт ====================

  /// Экспортировать все объекты в файл
  Future<ExportResult> exportObjects() async {
    return await _exportService.exportToFile();
  }

  /// Экспортировать и поделиться файлом
  Future<ExportResult> exportAndShareObjects() async {
    return await _exportService.exportAndShare();
  }

  /// Импортировать объекты из файла
  Future<ImportResult> importObjects() async {
    final result = await _exportService.importFromFile();

    if (result.success) {
      // Перезагружаем объекты после успешного импорта
      await _reloadObjects();
    }

    return result;
  }

  /// Получить статистику для экспорта
  Future<Map<String, dynamic>> getExportStats() async {
    return await _exportService.getExportStats();
  }

  // Приватные методы

  Future<void> _saveAndBroadcast(MapObject object) async {
    await _storage.saveObject(object);
    _objects.add(object);

    if (_p2pEnabled && _p2pService.isRunning) {
      await _p2pService.createAndBroadcastObject(object);
    }

    notifyListeners();
  }

  Future<void> _broadcastUpdate(MapObject object) async {
    if (_p2pEnabled && _p2pService.isRunning) {
      await _p2pService.createAndBroadcastObject(object);
    }
  }

  Future<void> _reloadObjects() async {
    _objects = await _storage.getAllObjects();
    _updateNearbyObjects();
    notifyListeners();
  }

  void _onNewObjectReceived(MapObject object) {
    // Добавляем в список если ещё нет
    final existingIndex = _objects.indexWhere((o) => o.id == object.id);
    if (existingIndex >= 0) {
      _objects[existingIndex] = object;
    } else {
      _objects.add(object);
    }

    _updateNearbyObjects();
    _checkAndNotifyNearby(object);
    notifyListeners();
  }

  void _updateNearbyObjects() {
    if (_userLat == null || _userLng == null) {
      _nearbyObjects = [];
      return;
    }

    _nearbyObjects = _objects.where((obj) {
      final distance = calculateDistance(
        _userLat!, _userLng!,
        obj.latitude, obj.longitude,
      );
      return distance <= 500; // 500 метров
    }).toList();
  }

  void _checkAndNotifyNearby(MapObject object) {
    if (_userLat == null || _userLng == null) return;

    final distance = calculateDistance(
      _userLat!, _userLng!,
      object.latitude, object.longitude,
    );

    if (distance <= 100) {
      debugPrint('📍 Рядом объект: ${object.type.emoji} ${object.shortDescription}');
      // TODO: Показать уведомление
    }
  }

  List<MapObject> _filterObjects(List<MapObject> objects) {
    return objects.where((obj) {
      // Фильтр по типу
      if (!_enabledTypes.contains(obj.type)) return false;

      // Фильтр по репутации создателя
      if (obj.ownerReputation < _minReputation) return false;

      // Фильтр скрытых объектов
      if (obj.status == MapObjectStatus.hidden) return false;

      // Фильтр убранных монстров
      if (!_showCleaned && obj.type == MapObjectType.trashMonster) {
        if ((obj as TrashMonster).isCleaned) return false;
      }

      // Фильтр истёкших существ
      if (obj.type == MapObjectType.creature) {
        if ((obj as Creature).isExpired) return false;
      }

      return true;
    }).toList();
  }

  // ==================== Профили контактов ====================

  /// Получить профиль контакта
  Future<ContactProfile?> getContactProfile(String userId) async {
    final json = await _storage.getContactProfile(userId);
    if (json == null) return null;
    
    // Конвертируем snake_case в camelCase
    final converted = <String, dynamic>{};
    json.forEach((key, value) {
      switch (key) {
        case 'user_id':
          converted['userId'] = value;
          break;
        case 'about':
          converted['about'] = value;
          break;
        case 'vk_link':
          converted['vkLink'] = value;
          break;
        case 'max_link':
          converted['maxLink'] = value;
          break;
        case 'visibility':
          converted['visibility'] = value;
          break;
        case 'accept_p2p_messages':
          converted['acceptP2PMessages'] = value == 1 || value == true;
          break;
        default:
          converted[key] = value;
      }
    });
    
    return ContactProfile.fromJson(converted);
  }

  /// Проверить, можно ли показать контакт
  Future<bool> canShowContact({
    required String ownerId,
    required String viewerId,
    required String noteId,
  }) async {
    final profile = await getContactProfile(ownerId);
    if (profile == null) return false;
    
    // Владелец всегда видит свой контакт
    if (ownerId == viewerId) return true;
    
    // Проверяем настройки видимости
    switch (profile.visibility) {
      case ContactVisibility.afterApproval:
        // Проверяем, одобрен ли контакт
        final interests = await getInterestsForNote(noteId);
        final interest = interests.firstWhere(
          (i) => i.userId == viewerId,
          orElse: () => NoteInterest(noteId: '', userId: '', timestamp: DateTime.now()),
        );
        return interest.contactApproved;
        
      case ContactVisibility.afterInterest:
        // Проверяем, есть ли "Интересно"
        return await hasInterest(noteId, viewerId);
        
      case ContactVisibility.nobody:
        return false;
    }
  }

  @override
  void dispose() {
    _objectsSubscription?.cancel();
    _newObjectSubscription?.cancel();
    _syncSubscription?.cancel();
    _storage.dispose();
    _p2pService.dispose();
    super.dispose();
  }
}
