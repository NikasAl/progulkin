import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/map_objects/map_objects.dart';
import '../models/contact_profile.dart';
import '../services/p2p/p2p.dart';
import '../services/map_object_export_service.dart';
import '../services/creature_service.dart'; // Для CatchResult
import '../services/interest_notification_service.dart'; // Для InterestNotification
import 'creature_provider.dart';
import 'p2p_provider.dart';
import 'moderation_provider.dart';
import 'notification_provider.dart';
import 'contact_provider.dart';
import 'interest_provider.dart';
import 'reminder_provider.dart';
import 'foraging_provider.dart';

/// Провайдер для управления объектами на карте
/// 
/// Служит фасадом для специализированных провайдеров:
/// - CreatureProvider - управление существами
/// - P2PProvider - P2P синхронизация
/// - ModerationProvider - модерация объектов
/// - NotificationProvider - уведомления
/// - ContactProvider - профили контактов
/// - InterestProvider - интересы к заметкам
/// - ReminderProvider - напоминания
/// - ForagingProvider - места сбора
class MapObjectProvider extends ChangeNotifier {
  final MapObjectStorage _storage = MapObjectStorage();
  final MapObjectExportService _exportService = MapObjectExportService();
  final Uuid _uuid = const Uuid();

  /// Доступ к хранилищу для прямого использования
  MapObjectStorage get storage => _storage;

  // Специализированные провайдеры (опционально)
  CreatureProvider? _creatureProvider;
  P2PProvider? _p2pProvider;
  ModerationProvider? _moderationProvider;
  NotificationProvider? _notificationProvider;
  ContactProvider? _contactProvider;
  InterestProvider? _interestProvider;
  ReminderProvider? _reminderProvider;
  ForagingProvider? _foragingProvider;

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
  bool get isP2PRunning => _p2pProvider?.isRunning ?? false;

  /// Количество объектов по типам (только отображаемые на карте)
  Map<MapObjectType, int> get objectCounts {
    final counts = <MapObjectType, int>{};
    final filteredObjects = objects;
    for (final type in MapObjectType.values) {
      counts[type] = filteredObjects.where((o) => o.type == type).length;
    }
    return counts;
  }

  /// Статистика (только отображаемые объекты)
  Map<String, int> get stats {
    final filteredObjects = objects;
    int total = filteredObjects.length;
    int trashMonsters = filteredObjects.where((o) => o.type == MapObjectType.trashMonster).length;
    int cleaned = filteredObjects.where((o) => o.type == MapObjectType.trashMonster)
        .where((o) => (o as TrashMonster).isCleaned).length;
    int secrets = filteredObjects.where((o) => o.type == MapObjectType.secretMessage).length;
    int creatures = filteredObjects.where((o) => o.type == MapObjectType.creature).length;

    return {
      'total': total,
      'trashMonsters': trashMonsters,
      'cleaned': cleaned,
      'secrets': secrets,
      'creatures': creatures,
    };
  }

  /// Конструктор без параметров (для обратной совместимости)
  MapObjectProvider();

  /// Конструктор с специализированными провайдерами
  MapObjectProvider.withProviders({
    CreatureProvider? creatureProvider,
    P2PProvider? p2pProvider,
    ModerationProvider? moderationProvider,
    NotificationProvider? notificationProvider,
    ContactProvider? contactProvider,
    InterestProvider? interestProvider,
    ReminderProvider? reminderProvider,
    ForagingProvider? foragingProvider,
  }) : _creatureProvider = creatureProvider,
       _p2pProvider = p2pProvider,
       _moderationProvider = moderationProvider,
       _notificationProvider = notificationProvider,
       _contactProvider = contactProvider,
       _interestProvider = interestProvider,
       _reminderProvider = reminderProvider,
       _foragingProvider = foragingProvider;

  /// Установить специализированные провайдеры
  void setProviders({
    CreatureProvider? creatureProvider,
    P2PProvider? p2pProvider,
    ModerationProvider? moderationProvider,
    NotificationProvider? notificationProvider,
    ContactProvider? contactProvider,
    InterestProvider? interestProvider,
    ReminderProvider? reminderProvider,
    ForagingProvider? foragingProvider,
  }) {
    if (creatureProvider != null) _creatureProvider = creatureProvider;
    if (p2pProvider != null) _p2pProvider = p2pProvider;
    if (moderationProvider != null) _moderationProvider = moderationProvider;
    if (notificationProvider != null) _notificationProvider = notificationProvider;
    if (contactProvider != null) _contactProvider = contactProvider;
    if (interestProvider != null) _interestProvider = interestProvider;
    if (reminderProvider != null) _reminderProvider = reminderProvider;
    if (foragingProvider != null) _foragingProvider = foragingProvider;
  }

  /// Инициализация
  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Загружаем объекты из локального хранилища
      _objects = await _storage.getAllObjects();
      
      // Очищаем истёкших диких существ при запуске
      await _cleanExpiredWildCreatures();

      // Инициализируем NotificationProvider
      if (_notificationProvider != null) {
        await _notificationProvider!.init();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('❌ Ошибка инициализации MapObjectProvider: $e');
      notifyListeners();
    }
  }

  /// Очистить истёкших диких существ из базы данных
  Future<int> _cleanExpiredWildCreatures() async {
    if (_creatureProvider != null) {
      return await _creatureProvider!.cleanExpiredWildCreatures(_objects);
    }
    
    // Fallback реализация
    int removed = 0;
    final toRemove = <String>[];
    
    for (final obj in _objects) {
      if (obj.type == MapObjectType.creature) {
        final creature = obj as Creature;
        if (creature.isWild && creature.isExpired) {
          toRemove.add(creature.id);
          removed++;
        }
      }
    }
    
    if (removed > 0) {
      debugPrint('🧹 Очистка: удалено $removed истёкших диких существ');
      for (final id in toRemove) {
        await _storage.deleteObject(id);
        _objects.removeWhere((o) => o.id == id);
      }
      notifyListeners();
    }
    
    return removed;
  }

  /// Очистить всех диких существ (при завершении прогулки)
  Future<int> cleanAllWildCreatures({String? keepForUserId}) async {
    if (_creatureProvider != null) {
      final removed = await _creatureProvider!.cleanAllWildCreatures(_objects);
      if (removed > 0) {
        _objects.removeWhere((o) => 
          o.type == MapObjectType.creature && (o as Creature).isWild);
        _updateNearbyObjects();
        notifyListeners();
      }
      return removed;
    }
    
    // Fallback реализация
    int removed = 0;
    final toRemove = <String>[];
    
    for (final obj in _objects) {
      if (obj.type == MapObjectType.creature) {
        final creature = obj as Creature;
        if (creature.isWild) {
          toRemove.add(creature.id);
          removed++;
        }
      }
    }
    
    if (removed > 0) {
      debugPrint('🧹 Очистка после прогулки: удалено $removed диких существ');
      for (final id in toRemove) {
        await _storage.deleteObject(id);
        _objects.removeWhere((o) => o.id == id);
      }
      _updateNearbyObjects();
      notifyListeners();
    }
    
    return removed;
  }

  // ==================== P2P ====================

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

    if (_p2pProvider != null) {
      await _p2pProvider!.start(
        signalingServer: signalingServer,
        signalingPort: signalingPort,
        deviceId: deviceId,
        userLat: _userLat!,
        userLng: _userLng!,
      );
      notifyListeners();
      return;
    }
    
    debugPrint('⚠️ P2PProvider не установлен');
  }

  /// Остановка P2P сервиса
  Future<void> stopP2P() async {
    if (_p2pProvider != null) {
      await _p2pProvider!.stop();
      notifyListeners();
    }
  }

  /// Обновление позиции пользователя
  void updateUserPosition(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    _updateNearbyObjects();
    notifyListeners();
  }

  // ==================== Создание объектов ====================

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
    if (_creatureProvider != null) {
      final creature = await _creatureProvider!.spawnCreature(
        id: _uuid.v4(),
        latitude: latitude,
        longitude: longitude,
        creatureType: creatureType,
        rarity: rarity,
        habitat: habitat,
        lifetimeMinutes: lifetimeMinutes,
      );
      _objects.add(creature);
      notifyListeners();
      return creature;
    }
    
    // Fallback реализация
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

  /// Спавн существ вокруг игрока
  Future<List<Creature>> spawnCreaturesAroundPlayer({
    required double playerLat,
    required double playerLng,
    int maxCreatures = 2,
    double radiusKm = 1.5,
  }) async {
    if (_creatureProvider != null) {
      final spawned = await _creatureProvider!.spawnCreaturesAroundPlayer(
        generateId: () => _uuid.v4(),
        playerLat: playerLat,
        playerLng: playerLng,
        maxCreatures: maxCreatures,
        radiusKm: radiusKm,
      );
      _objects.addAll(spawned);
      notifyListeners();
      return spawned;
    }
    
    // Fallback - нужен CreatureService
    debugPrint('⚠️ CreatureProvider не установлен, спавн невозможен');
    return [];
  }

  /// Попытка поимки существа с расчётом шанса
  Future<CatchResult> attemptCatchCreature({
    required String creatureId,
    required String userId,
    required String userName,
    required int playerLevel,
    double? userLat,
    double? userLng,
  }) async {
    if (_creatureProvider != null) {
      final result = await _creatureProvider!.attemptCatchCreature(
        creatureId: creatureId,
        userId: userId,
        userName: userName,
        playerLevel: playerLevel,
        userLat: userLat,
        userLng: userLng,
      );
      if (result.isSuccess) {
        final index = _objects.indexWhere((o) => o.id == creatureId);
        if (index >= 0) {
          final obj = await _storage.getObject(creatureId);
          if (obj != null) _objects[index] = obj;
        }
        notifyListeners();
      }
      return result;
    }
    
    // Fallback реализация
    final obj = await _storage.getObject(creatureId);
    if (obj == null || obj is! Creature) {
      return CatchResult.failed(
        creature: Creature.spawnWild(
          id: '',
          latitude: 0,
          longitude: 0,
          creatureType: CreatureType.domovoy,
          rarity: CreatureRarity.common,
          habitat: CreatureHabitat.anywhere,
        ),
        chance: 0,
      );
    }

    if (!obj.isWild) {
      return CatchResult.failed(creature: obj, chance: 0, escaped: false);
    }

    if (userLat != null && userLng != null) {
      final distance = calculateDistance(userLat, userLng, obj.latitude, obj.longitude);
      if (distance > 25) {
        return CatchResult.failed(creature: obj, chance: 0, escaped: false);
      }
    }

    // Простая логика поимки для fallback
    final caught = obj.catchCreature(userId, userName);
    await _storage.updateObject(caught);
    await _broadcastUpdate(caught);

    final index = _objects.indexWhere((o) => o.id == creatureId);
    if (index >= 0) {
      _objects[index] = caught;
    }
    notifyListeners();

    return CatchResult.success(creature: caught, chance: 100, points: caught.catchPoints);
  }

  /// Получить коллекцию пойманных существ пользователя
  List<Creature> getUserCreatureCollection(String userId) {
    if (_creatureProvider != null) {
      return _creatureProvider!.getUserCreatureCollection(userId);
    }
    return _objects.whereType<Creature>().where((c) => c.caughtBy == userId).toList();
  }

  /// Получить диких существ рядом с игроком
  List<Creature> getWildCreaturesNearby() {
    if (_creatureProvider != null) {
      return _creatureProvider!.getWildCreaturesNearby(_nearbyObjects);
    }
    return _nearbyObjects.whereType<Creature>().where((c) => c.isWild && c.isAlive).toList();
  }

  /// Получить статистику коллекции существ
  Map<String, dynamic> getCreatureCollectionStats(String userId) {
    if (_creatureProvider != null) {
      return _creatureProvider!.getCreatureCollectionStats(userId);
    }
    
    final collection = getUserCreatureCollection(userId);
    final byRarity = <CreatureRarity, int>{};
    for (final rarity in CreatureRarity.values) {
      byRarity[rarity] = collection.where((c) => c.rarity == rarity).length;
    }
    return {
      'total': collection.length,
      'byRarity': byRarity,
      'totalPoints': collection.fold(0, (sum, c) => sum + c.catchPoints),
    };
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

  /// Создание места для сбора
  Future<ForagingSpot> createForagingSpot({
    required double latitude,
    required double longitude,
    required String ownerId,
    String ownerName = 'Аноним',
    int ownerReputation = 0,
    required ForagingCategory category,
    required String itemTypeCode,
    required ForagingQuantity quantity,
    ForagingSeason season = ForagingSeason.summer,
    String notes = '',
    List<String>? photoIds,
  }) async {
    final spot = ForagingSpot(
      id: _uuid.v4(),
      latitude: latitude,
      longitude: longitude,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerReputation: ownerReputation,
      category: category,
      itemTypeCode: itemTypeCode,
      quantity: quantity,
      season: season,
      notes: notes,
      photoIds: photoIds,
    );

    await _saveAndBroadcast(spot);
    return spot;
  }

  // ==================== Места сбора (делегирование ForagingProvider) ====================

  /// Отметить сбор в месте
  Future<void> markForagingHarvest(String spotId) async {
    if (_foragingProvider != null) {
      await _foragingProvider!.markHarvest(spotId);
      _updateObjectFromStorage(spotId);
      return;
    }
    
    final obj = await _storage.getObject(spotId);
    if (obj == null || obj is! ForagingSpot) return;

    final updated = obj.markHarvest();
    await _storage.updateObject(updated);
    await _broadcastUpdate(updated);

    final index = _objects.indexWhere((o) => o.id == spotId);
    if (index >= 0) {
      _objects[index] = updated;
    }
    notifyListeners();
  }

  /// Подтвердить место сбора
  Future<void> verifyForagingSpot(String spotId) async {
    if (_foragingProvider != null) {
      await _foragingProvider!.verifySpot(spotId);
      _updateObjectFromStorage(spotId);
      return;
    }
    
    final obj = await _storage.getObject(spotId);
    if (obj == null || obj is! ForagingSpot) return;

    final updated = obj.verify();
    await _storage.updateObject(updated);
    await _broadcastUpdate(updated);

    final index = _objects.indexWhere((o) => o.id == spotId);
    if (index >= 0) {
      _objects[index] = updated;
    }
    notifyListeners();
  }

  /// Получить места сбора рядом с пользователем
  List<ForagingSpot> getForagingSpotsNearby() {
    if (_foragingProvider != null) {
      return _foragingProvider!.getSpotsNearby();
    }
    return _nearbyObjects.whereType<ForagingSpot>().where((s) => !s.isDeleted).toList();
  }

  /// Получить места сбора по категории
  List<ForagingSpot> getForagingSpotsByCategory(ForagingCategory category) {
    if (_foragingProvider != null) {
      return _foragingProvider!.getSpotsByCategory(category);
    }
    return _objects.whereType<ForagingSpot>()
        .where((s) => s.category == category && !s.isDeleted).toList();
  }

  /// Получить места сбора в сезон
  List<ForagingSpot> getForagingSpotsInSeason() {
    if (_foragingProvider != null) {
      return _foragingProvider!.getSpotsInSeason();
    }
    return _objects.whereType<ForagingSpot>()
        .where((s) => s.isInSeason && !s.isDeleted).toList();
  }

  // ==================== Интересы (делегирование InterestProvider) ====================

  /// Добавить "Интересно" к заметке
  Future<void> addInterestToNote(String noteId, String userId) async {
    if (_interestProvider != null) {
      await _interestProvider!.addInterestToNote(noteId, userId);
      _updateObjectFromStorage(noteId);
      return;
    }
    
    await _storage.addInterest(noteId: noteId, userId: userId);
    
    final obj = await _storage.getObject(noteId);
    if (obj == null || obj is! InterestNote) return;

    final updated = obj.addInterest(userId);
    await _storage.updateObject(updated);
    await _broadcastUpdate(updated);
    
    final index = _objects.indexWhere((o) => o.id == noteId);
    if (index >= 0) {
      _objects[index] = updated;
    }
    notifyListeners();
  }

  /// Убрать "Интересно" с заметки
  Future<void> removeInterestFromNote(String noteId, String userId) async {
    if (_interestProvider != null) {
      await _interestProvider!.removeInterestFromNote(noteId, userId);
      _updateObjectFromStorage(noteId);
      return;
    }
    
    await _storage.removeInterest(noteId, userId);
    
    final obj = await _storage.getObject(noteId);
    if (obj == null || obj is! InterestNote) return;

    final updated = obj.removeInterest(userId);
    await _storage.updateObject(updated);
    await _broadcastUpdate(updated);
    
    final index = _objects.indexWhere((o) => o.id == noteId);
    if (index >= 0) {
      _objects[index] = updated;
    }
    notifyListeners();
  }

  /// Получить список пользователей, отметивших "Интересно"
  Future<List<NoteInterest>> getInterestsForNote(String noteId) async {
    if (_interestProvider != null) {
      return await _interestProvider!.getInterestsForNote(noteId);
    }
    final results = await _storage.getInterestsForNote(noteId);
    return results.map((json) => NoteInterest.fromJson(json)).toList();
  }

  /// Проверил ли пользователь "Интересно" на заметке
  Future<bool> hasInterest(String noteId, String userId) async {
    if (_interestProvider != null) {
      return await _interestProvider!.hasInterest(noteId, userId);
    }
    final interests = await getInterestsForNote(noteId);
    return interests.any((i) => i.userId == userId);
  }

  /// Запросить контакт у автора заметки
  Future<void> requestContact(String noteId, String userId) async {
    if (_interestProvider != null) {
      await _interestProvider!.requestContact(noteId, userId);
      return;
    }
    await _storage.addInterest(noteId: noteId, userId: userId, contactRequestSent: true);
  }

  /// Одобрить запрос на контакт
  Future<void> approveContactRequest(String noteId, String userId) async {
    if (_interestProvider != null) {
      await _interestProvider!.approveContactRequest(noteId, userId);
      return;
    }
    await _storage.addInterest(
      noteId: noteId,
      userId: userId,
      contactRequestSent: true,
      contactApproved: true,
    );
  }

  // ==================== Модерация ====================

  /// Подтвердить объект
  Future<void> confirmObject(String objectId) async {
    if (_moderationProvider != null) {
      await _moderationProvider!.confirmObject(objectId);
      _updateObjectFromStorage(objectId);
      _updateNearbyObjects();
      notifyListeners();
      return;
    }
    
    final obj = await _storage.getObject(objectId);
    if (obj == null) return;

    obj.confirms++;
    obj.incrementVersion();

    await _storage.updateObject(obj);
    await _broadcastUpdate(obj);

    final index = _objects.indexWhere((o) => o.id == objectId);
    if (index >= 0) {
      _objects[index] = obj;
    }
    _updateNearbyObjects();
    notifyListeners();
  }

  /// Опровергнуть объект
  Future<void> denyObject(String objectId) async {
    if (_moderationProvider != null) {
      await _moderationProvider!.denyObject(objectId);
      _updateObjectFromStorage(objectId);
      _updateNearbyObjects();
      notifyListeners();
      return;
    }
    
    final obj = await _storage.getObject(objectId);
    if (obj == null) return;

    obj.denies++;
    obj.incrementVersion();

    if (obj.shouldBeHidden) {
      obj.status = MapObjectStatus.hidden;
    }

    await _storage.updateObject(obj);
    await _broadcastUpdate(obj);

    final index = _objects.indexWhere((o) => o.id == objectId);
    if (index >= 0) {
      _objects[index] = obj;
    }
    _updateNearbyObjects();
    notifyListeners();
  }

  /// Отметить монстра как убранного
  Future<void> cleanTrashMonster(String objectId, String userId) async {
    if (_moderationProvider != null) {
      await _moderationProvider!.cleanTrashMonster(objectId, userId);
      _updateObjectFromStorage(objectId);
      _updateNearbyObjects();
      notifyListeners();
      return;
    }
    
    final obj = await _storage.getObject(objectId);
    if (obj == null || obj is! TrashMonster) return;

    final cleaned = obj.markAsCleaned(userId);
    await _storage.updateObject(cleaned);
    await _broadcastUpdate(cleaned);

    final index = _objects.indexWhere((o) => o.id == objectId);
    if (index >= 0) {
      _objects[index] = cleaned;
    }
    _updateNearbyObjects();
    notifyListeners();
  }

  /// Поймать существо
  Future<bool> catchCreature(
    String objectId,
    String userId,
    String userName, {
    double? userLat,
    double? userLng,
  }) async {
    if (_creatureProvider != null) {
      final success = await _creatureProvider!.catchCreature(
        objectId, userId, userName,
        userLat: userLat, userLng: userLng,
      );
      if (success) {
        _updateObjectFromStorage(objectId);
        _updateNearbyObjects();
        notifyListeners();
      }
      return success;
    }
    
    final obj = await _storage.getObject(objectId);
    if (obj == null || obj is! Creature) return false;

    if (userLat != null && userLng != null) {
      final distance = calculateDistance(userLat, userLng, obj.latitude, obj.longitude);
      if (distance > 25) {
        debugPrint('⚠️ Попытка поймать существо с расстояния ${distance.toInt()}м');
        return false;
      }
    }

    final caught = obj.catchCreature(userId, userName);
    await _storage.updateObject(caught);
    await _broadcastUpdate(caught);

    final index = _objects.indexWhere((o) => o.id == objectId);
    if (index >= 0) {
      _objects[index] = caught;
    }
    _updateNearbyObjects();
    notifyListeners();
    return true;
  }

  // ==================== Напоминания (делегирование ReminderProvider) ====================

  /// Активировать напоминание
  Future<void> activateReminder(String reminderId) async {
    if (_reminderProvider != null) {
      await _reminderProvider!.activateReminder(reminderId);
      _updateObjectFromStorage(reminderId);
      return;
    }
    
    final obj = await _storage.getObject(reminderId);
    if (obj == null || obj is! ReminderCharacter) return;

    final activated = obj.activate();
    await _storage.updateObject(activated);
    await _broadcastUpdate(activated);

    final index = _objects.indexWhere((o) => o.id == reminderId);
    if (index >= 0) {
      _objects[index] = activated;
    }
    notifyListeners();
  }

  /// Деактивировать напоминание
  Future<void> deactivateReminder(String reminderId) async {
    if (_reminderProvider != null) {
      await _reminderProvider!.deactivateReminder(reminderId);
      _updateObjectFromStorage(reminderId);
      return;
    }
    
    final obj = await _storage.getObject(reminderId);
    if (obj == null || obj is! ReminderCharacter) return;

    final deactivated = obj.deactivate();
    await _storage.updateObject(deactivated);
    await _broadcastUpdate(deactivated);

    final index = _objects.indexWhere((o) => o.id == reminderId);
    if (index >= 0) {
      _objects[index] = deactivated;
    }
    notifyListeners();
  }

  /// Отложить напоминание
  Future<void> snoozeReminder(String reminderId, Duration duration) async {
    if (_reminderProvider != null) {
      await _reminderProvider!.snoozeReminder(reminderId, duration);
      _updateObjectFromStorage(reminderId);
      return;
    }
    
    final obj = await _storage.getObject(reminderId);
    if (obj == null || obj is! ReminderCharacter) return;

    final snoozed = obj.snooze(duration);
    await _storage.updateObject(snoozed);
    await _broadcastUpdate(snoozed);

    final index = _objects.indexWhere((o) => o.id == reminderId);
    if (index >= 0) {
      _objects[index] = snoozed;
    }
    notifyListeners();
  }

  /// Получить напоминания пользователя
  List<ReminderCharacter> getUserReminders(String userId) {
    if (_reminderProvider != null) {
      return _reminderProvider!.getUserReminders(userId);
    }
    return _objects.whereType<ReminderCharacter>().where((r) => r.ownerId == userId).toList();
  }

  /// Получить активные напоминания пользователя
  List<ReminderCharacter> getActiveReminders(String userId) {
    if (_reminderProvider != null) {
      return _reminderProvider!.getActiveReminders(userId);
    }
    return _objects.whereType<ReminderCharacter>()
        .where((r) => r.ownerId == userId && r.isActive).toList();
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

  // ==================== Фильтры ====================

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
    if (!enabled && (_p2pProvider?.isRunning ?? false)) {
      stopP2P();
    }
    notifyListeners();
  }

  /// Принудительная синхронизация
  Future<void> forceSync() async {
    if (_p2pProvider != null) {
      await _p2pProvider!.forceSync();
    }
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
      await _reloadObjects();
    }

    return result;
  }

  /// Получить статистику для экспорта
  Future<Map<String, dynamic>> getExportStats() async {
    return await _exportService.getExportStats();
  }

  // ==================== Профили контактов ====================

  /// Получить профиль контакта
  Future<ContactProfile?> getContactProfile(String userId) async {
    if (_contactProvider != null) {
      return await _contactProvider!.getContactProfile(userId);
    }
    
    final json = await _storage.getContactProfile(userId);
    if (json == null) return null;
    
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
    if (_contactProvider != null) {
      return await _contactProvider!.canShowContact(
        ownerId: ownerId,
        viewerId: viewerId,
        noteId: noteId,
        hasInterest: hasInterest,
        getInterestsForNote: getInterestsForNote,
      );
    }
    
    final profile = await getContactProfile(ownerId);
    if (profile == null) return false;
    
    if (ownerId == viewerId) return true;
    
    switch (profile.visibility) {
      case ContactVisibility.afterApproval:
        final interests = await getInterestsForNote(noteId);
        final interest = interests.firstWhere(
          (i) => i.userId == viewerId,
          orElse: () => NoteInterest(noteId: '', userId: '', timestamp: DateTime.now()),
        );
        return interest.contactApproved;
        
      case ContactVisibility.afterInterest:
        return await hasInterest(noteId, viewerId);
        
      case ContactVisibility.nobody:
        return false;
    }
  }

  // ==================== Модерация фото ====================

  /// Проголосовать за фото (подтвердить)
  Future<void> confirmPhoto(String photoId, String userId) async {
    await _storage.votePhoto(photoId: photoId, userId: userId, vote: 1);
    notifyListeners();
  }

  /// Пожаловаться на фото
  Future<void> complainPhoto(String photoId, String userId) async {
    await _storage.votePhoto(photoId: photoId, userId: userId, vote: -1);
    notifyListeners();
  }

  /// Получить статистику голосов за фото
  Future<Map<String, int>> getPhotoVoteStats(String photoId) async {
    return await _storage.getPhotoVoteStats(photoId);
  }

  /// Получить голос пользователя за фото
  Future<int?> getUserPhotoVote(String photoId, String userId) async {
    return await _storage.getUserPhotoVote(photoId, userId);
  }

  /// Получить фото на модерации
  Future<List<Map<String, dynamic>>> getPhotosForModeration() async {
    return await _storage.getPhotosForModeration();
  }

  // ==================== Уведомления ====================

  /// Получить непрочитанные уведомления
  Future<List<InterestNotification>> getUnreadNotifications() async {
    if (_notificationProvider != null) {
      return await _notificationProvider!.getUnreadNotifications();
    }
    return [];
  }

  /// Получить количество непрочитанных уведомлений
  Future<int> getUnreadNotificationCount() async {
    if (_notificationProvider != null) {
      return await _notificationProvider!.getUnreadCount();
    }
    return 0;
  }

  /// Отметить уведомление как прочитанное
  Future<void> markNotificationRead(String notificationId) async {
    if (_notificationProvider != null) {
      await _notificationProvider!.markAsRead(notificationId);
      notifyListeners();
    }
  }

  /// Stream уведомлений
  Stream<InterestNotification>? get notificationStream => _notificationProvider?.notificationStream;

  // ==================== Интеграция с специализированными провайдерами ====================

  /// Обновить объект из специализированного провайдера
  void updateObjectFromProvider(String id, MapObject updated) {
    final index = _objects.indexWhere((o) => o.id == id);
    if (index >= 0) {
      _objects[index] = updated;
      _updateNearbyObjects();
      notifyListeners();
    }
  }

  /// Обработать объект, полученный через P2P от P2PProvider
  void onObjectReceivedFromP2P(MapObject object) {
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

  /// Принудительно обновить список nearby объектов
  void refreshNearbyObjects() {
    _updateNearbyObjects();
    notifyListeners();
  }

  /// Получить текущую позицию пользователя
  (double? lat, double? lng) get userPosition => (_userLat, _userLng);

  // ==================== Приватные методы ====================

  Future<void> _saveAndBroadcast(MapObject object) async {
    await _storage.saveObject(object);
    _objects.add(object);

    if (_p2pProvider != null) {
      await _p2pProvider!.broadcastObject(object);
    }

    notifyListeners();
  }

  Future<void> _broadcastUpdate(MapObject object) async {
    if (_p2pProvider != null) {
      await _p2pProvider!.broadcastObject(object);
    }
  }

  Future<void> _reloadObjects() async {
    _objects = await _storage.getAllObjects();
    _updateNearbyObjects();
    notifyListeners();
  }

  void _updateObjectFromStorage(String objectId) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null) return;
    
    final index = _objects.indexWhere((o) => o.id == objectId);
    if (index >= 0) {
      _objects[index] = obj;
      notifyListeners();
    }
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
    }
  }

  List<MapObject> _filterObjects(List<MapObject> objects) {
    return objects.where((obj) {
      if (!_enabledTypes.contains(obj.type)) return false;
      if (obj.ownerReputation < _minReputation) return false;
      if (obj.status == MapObjectStatus.hidden) return false;

      if (!_showCleaned && obj.type == MapObjectType.trashMonster) {
        if ((obj as TrashMonster).isCleaned) return false;
      }

      if (obj.type == MapObjectType.creature) {
        final creature = obj as Creature;
        if (creature.isExpired || !creature.isWild) return false;
      }

      return true;
    }).toList();
  }

  @override
  void dispose() {
    _storage.dispose();
    super.dispose();
  }
}
