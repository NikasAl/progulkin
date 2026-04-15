import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/map_objects/map_objects.dart';
import '../models/contact_profile.dart';
import '../services/p2p/p2p.dart';
import '../services/map_object_export_service.dart';
import '../services/creature_service.dart';
import '../services/interest_notification_service.dart';
import '../di/service_locator.dart';
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
/// Служит фасадом для специализированных провайдеров.
/// Делегирует специфичные операции соответствующим провайдерам.
class MapObjectProvider extends ChangeNotifier {
  final MapObjectStorage _storage = getIt<MapObjectStorage>();
  final MapObjectExportService _exportService = getIt<MapObjectExportService>();
  final Uuid _uuid = const Uuid();

  /// Доступ к хранилищу
  MapObjectStorage get storage => _storage;

  // Специализированные провайдеры
  CreatureProvider? _creatureProvider;
  P2PProvider? _p2pProvider;
  ModerationProvider? _moderationProvider;
  NotificationProvider? _notificationProvider;
  ContactProvider? _contactProvider;
  InterestProvider? _interestProvider;
  ReminderProvider? _reminderProvider;
  ForagingProvider? _foragingProvider;

  // Состояние
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

  // Позиция пользователя
  double? _userLat;
  double? _userLng;

  // ==================== Геттеры ====================

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
  (double? lat, double? lng) get userPosition => (_userLat, _userLng);

  Map<MapObjectType, int> get objectCounts {
    final counts = <MapObjectType, int>{};
    for (final type in MapObjectType.values) {
      counts[type] = objects.where((o) => o.type == type).length;
    }
    return counts;
  }

  Map<String, int> get stats {
    return {
      'total': objects.length,
      'trashMonsters': objects.where((o) => o.type == MapObjectType.trashMonster).length,
      'cleaned': objects.where((o) => o.type == MapObjectType.trashMonster)
          .where((o) => (o as TrashMonster).isCleaned).length,
      'secrets': objects.where((o) => o.type == MapObjectType.secretMessage).length,
      'creatures': objects.where((o) => o.type == MapObjectType.creature).length,
    };
  }

  // ==================== Конструкторы ====================

  MapObjectProvider();

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
    _creatureProvider = creatureProvider ?? _creatureProvider;
    _p2pProvider = p2pProvider ?? _p2pProvider;
    _moderationProvider = moderationProvider ?? _moderationProvider;
    _notificationProvider = notificationProvider ?? _notificationProvider;
    _contactProvider = contactProvider ?? _contactProvider;
    _interestProvider = interestProvider ?? _interestProvider;
    _reminderProvider = reminderProvider ?? _reminderProvider;
    _foragingProvider = foragingProvider ?? _foragingProvider;
  }

  // ==================== Инициализация ====================

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _objects = await _storage.getAllObjects();
      await _creatureProvider?.cleanExpiredWildCreatures(_objects);
      await _notificationProvider?.init();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('❌ Ошибка инициализации MapObjectProvider: $e');
      notifyListeners();
    }
  }

  // ==================== Управление списками ====================

  void updateUserPosition(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    _updateNearbyObjects();
    notifyListeners();
  }

  void updateObjectFromProvider(String id, MapObject updated) {
    final index = _objects.indexWhere((o) => o.id == id);
    if (index >= 0) {
      _objects[index] = updated;
      _updateNearbyObjects();
      notifyListeners();
    }
  }

  void onObjectReceivedFromP2P(MapObject object) {
    final index = _objects.indexWhere((o) => o.id == object.id);
    if (index >= 0) {
      _objects[index] = object;
    } else {
      _objects.add(object);
    }
    _updateNearbyObjects();
    notifyListeners();
  }

  void refreshNearbyObjects() {
    _updateNearbyObjects();
    notifyListeners();
  }

  Future<void> reload() async {
    _objects = await _storage.getAllObjects();
    _updateNearbyObjects();
    notifyListeners();
  }

  // ==================== Создание объектов ====================

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

  // ==================== Делегирование: Существа ====================

  Future<Creature> spawnCreature({
    required double latitude,
    required double longitude,
    required CreatureType creatureType,
    required CreatureRarity rarity,
    required CreatureHabitat habitat,
    int lifetimeMinutes = 60,
  }) async {
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

  Future<List<Creature>> spawnCreaturesAroundPlayer({
    required double playerLat,
    required double playerLng,
    int maxCreatures = 2,
    double radiusKm = 1.5,
  }) async {
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

  Future<CatchResult> attemptCatchCreature({
    required String creatureId,
    required String userId,
    required String userName,
    required int playerLevel,
    double? userLat,
    double? userLng,
  }) async {
    final result = await _creatureProvider!.attemptCatchCreature(
      creatureId: creatureId,
      userId: userId,
      userName: userName,
      playerLevel: playerLevel,
      userLat: userLat,
      userLng: userLng,
    );
    if (result.isSuccess) {
      _reloadObjectFromStorage(creatureId);
    }
    return result;
  }

  Future<bool> catchCreature(String objectId, String userId, String userName, {double? userLat, double? userLng}) async {
    final success = await _creatureProvider!.catchCreature(objectId, userId, userName, userLat: userLat, userLng: userLng);
    if (success) {
      _reloadObjectFromStorage(objectId);
      _updateNearbyObjects();
      notifyListeners();
    }
    return success;
  }

  Future<int> cleanAllWildCreatures({String? keepForUserId}) async {
    final removed = await _creatureProvider!.cleanAllWildCreatures(_objects);
    if (removed > 0) {
      _objects.removeWhere((o) => o.type == MapObjectType.creature && (o as Creature).isWild);
      _updateNearbyObjects();
      notifyListeners();
    }
    return removed;
  }

  List<Creature> getUserCreatureCollection(String userId) => _creatureProvider!.getUserCreatureCollection(userId);
  List<Creature> getWildCreaturesNearby() => _creatureProvider!.getWildCreaturesNearby(_nearbyObjects);
  Map<String, dynamic> getCreatureCollectionStats(String userId) => _creatureProvider!.getCreatureCollectionStats(userId);

  // ==================== Делегирование: P2P ====================

  Future<void> startP2P({required String signalingServer, required int signalingPort, required String deviceId}) async {
    if (!_p2pEnabled || _userLat == null || _userLng == null) return;
    await _p2pProvider!.start(
      signalingServer: signalingServer,
      signalingPort: signalingPort,
      deviceId: deviceId,
      userLat: _userLat!,
      userLng: _userLng!,
    );
    notifyListeners();
  }

  Future<void> stopP2P() async {
    await _p2pProvider!.stop();
    notifyListeners();
  }

  Future<void> forceSync() async => await _p2pProvider!.forceSync();
  void setP2PEnabled(bool enabled) {
    _p2pEnabled = enabled;
    if (!enabled && (_p2pProvider?.isRunning ?? false)) stopP2P();
    notifyListeners();
  }

  // ==================== Делегирование: Модерация ====================

  Future<void> confirmObject(String objectId) async {
    await _moderationProvider!.confirmObject(objectId);
    _reloadObjectFromStorage(objectId);
    _updateNearbyObjects();
    notifyListeners();
  }

  Future<void> denyObject(String objectId) async {
    await _moderationProvider!.denyObject(objectId);
    _reloadObjectFromStorage(objectId);
    _updateNearbyObjects();
    notifyListeners();
  }

  Future<void> cleanTrashMonster(String objectId, String userId) async {
    await _moderationProvider!.cleanTrashMonster(objectId, userId);
    _reloadObjectFromStorage(objectId);
    _updateNearbyObjects();
    notifyListeners();
  }

  Future<void> confirmPhoto(String photoId, String userId) async => await _moderationProvider!.confirmPhoto(photoId, userId);
  Future<void> complainPhoto(String photoId, String userId) async => await _moderationProvider!.complainPhoto(photoId, userId);
  Future<Map<String, int>> getPhotoVoteStats(String photoId) async => await _moderationProvider!.getPhotoVoteStats(photoId);
  Future<int?> getUserPhotoVote(String photoId, String userId) async => await _moderationProvider!.getUserPhotoVote(photoId, userId);
  Future<List<Map<String, dynamic>>> getPhotosForModeration() async => await _moderationProvider!.getPhotosForModeration();

  // ==================== Делегирование: Уведомления ====================

  Future<List<InterestNotification>> getUnreadNotifications() async => await _notificationProvider!.getUnreadNotifications();
  Future<int> getUnreadNotificationCount() async => await _notificationProvider!.getUnreadCount();
  Future<void> markNotificationRead(String notificationId) async {
    await _notificationProvider!.markAsRead(notificationId);
    notifyListeners();
  }
  Stream<InterestNotification>? get notificationStream => _notificationProvider?.notificationStream;

  // ==================== Делегирование: Контакты ====================

  Future<ContactProfile?> getContactProfile(String userId) async => await _contactProvider!.getContactProfile(userId);
  
  Future<bool> canShowContact({required String ownerId, required String viewerId, required String noteId}) async {
    return await _contactProvider!.canShowContact(
      ownerId: ownerId,
      viewerId: viewerId,
      noteId: noteId,
      hasInterest: (n, u) => hasInterest(n, u),
      getInterestsForNote: (n) => getInterestsForNote(n),
    );
  }

  // ==================== Делегирование: Интересы ====================

  Future<void> addInterestToNote(String noteId, String userId) async {
    await _interestProvider!.addInterestToNote(noteId, userId);
    _reloadObjectFromStorage(noteId);
  }

  Future<void> removeInterestFromNote(String noteId, String userId) async {
    await _interestProvider!.removeInterestFromNote(noteId, userId);
    _reloadObjectFromStorage(noteId);
  }

  Future<List<NoteInterest>> getInterestsForNote(String noteId) async => await _interestProvider!.getInterestsForNote(noteId);
  Future<bool> hasInterest(String noteId, String userId) async => await _interestProvider!.hasInterest(noteId, userId);
  Future<void> requestContact(String noteId, String userId) async => await _interestProvider!.requestContact(noteId, userId);
  Future<void> approveContactRequest(String noteId, String userId) async => await _interestProvider!.approveContactRequest(noteId, userId);

  // ==================== Делегирование: Напоминания ====================

  Future<void> activateReminder(String reminderId) async {
    await _reminderProvider!.activateReminder(reminderId);
    _reloadObjectFromStorage(reminderId);
  }

  Future<void> deactivateReminder(String reminderId) async {
    await _reminderProvider!.deactivateReminder(reminderId);
    _reloadObjectFromStorage(reminderId);
  }

  Future<void> snoozeReminder(String reminderId, Duration duration) async {
    await _reminderProvider!.snoozeReminder(reminderId, duration);
    _reloadObjectFromStorage(reminderId);
  }

  List<ReminderCharacter> getUserReminders(String userId) => _reminderProvider!.getUserReminders(userId);
  List<ReminderCharacter> getActiveReminders(String userId) => _reminderProvider!.getActiveReminders(userId);

  // ==================== Делегирование: Места сбора ====================

  Future<void> markForagingHarvest(String spotId) async {
    await _foragingProvider!.markHarvest(spotId);
    _reloadObjectFromStorage(spotId);
  }

  Future<void> verifyForagingSpot(String spotId) async {
    await _foragingProvider!.verifySpot(spotId);
    _reloadObjectFromStorage(spotId);
  }

  List<ForagingSpot> getForagingSpotsNearby() => _foragingProvider!.getSpotsNearby();
  List<ForagingSpot> getForagingSpotsByCategory(ForagingCategory category) => _foragingProvider!.getSpotsByCategory(category);
  List<ForagingSpot> getForagingSpotsInSeason() => _foragingProvider!.getSpotsInSeason();

  // ==================== Базовые операции ====================

  Future<String?> readSecretMessage(String objectId, String userId) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null || obj is! SecretMessage || _userLat == null || _userLng == null) return null;

    final content = obj.decryptContent(userId, _userLat!, _userLng!);
    if (content != null) {
      final updated = obj.markAsRead(userId);
      await _storage.updateObject(updated);
      await _p2pProvider?.broadcastObject(updated);
      notifyListeners();
    }
    return content;
  }

  Future<void> deleteObject(String objectId, String userId) async {
    final obj = await _storage.getObject(objectId);
    if (obj == null) return;
    if (obj.ownerId != userId) throw Exception('Можно удалить только свои объекты');
    await _storage.deleteObject(objectId);
    _objects.removeWhere((o) => o.id == objectId);
    notifyListeners();
  }

  Future<MapObject?> getObject(String id) async => await _storage.getObject(id);
  Future<List<MapObject>> getObjectsInRadius(double lat, double lng, double radiusMeters) async =>
      await _storage.getObjectsInRadius(lat, lng, radiusMeters);

  // ==================== Фильтры ====================

  void toggleObjectType(MapObjectType type) {
    _enabledTypes.contains(type) ? _enabledTypes.remove(type) : _enabledTypes.add(type);
    notifyListeners();
  }

  void setSelectedType(MapObjectType? type) { _selectedType = type; notifyListeners(); }
  void setShowCleaned(bool show) { _showCleaned = show; notifyListeners(); }
  void setMinReputation(int reputation) { _minReputation = reputation; notifyListeners(); }

  // ==================== Экспорт/Импорт ====================

  Future<ExportResult> exportObjects() async => await _exportService.exportToFile();
  Future<ExportResult> exportAndShareObjects() async => await _exportService.exportAndShare();
  Future<Map<String, dynamic>> getExportStats() async => await _exportService.getExportStats();

  Future<ImportResult> importObjects() async {
    final result = await _exportService.importFromFile();
    if (result.success) await reload();
    return result;
  }

  Future<void> clearAll() async {
    await _storage.clearAll();
    _objects = [];
    _nearbyObjects = [];
    notifyListeners();
  }

  // ==================== Приватные методы ====================

  Future<void> _saveAndBroadcast(MapObject object) async {
    await _storage.saveObject(object);
    _objects.add(object);
    await _p2pProvider?.broadcastObject(object);
    notifyListeners();
  }

  Future<void> _reloadObjectFromStorage(String objectId) async {
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
      final distance = calculateDistance(_userLat!, _userLng!, obj.latitude, obj.longitude);
      return distance <= 500;
    }).toList();
  }

  List<MapObject> _filterObjects(List<MapObject> objects) {
    return objects.where((obj) {
      if (!_enabledTypes.contains(obj.type)) return false;
      if (obj.ownerReputation < _minReputation) return false;
      if (obj.status == MapObjectStatus.hidden) return false;
      if (!_showCleaned && obj.type == MapObjectType.trashMonster && (obj as TrashMonster).isCleaned) return false;
      if (obj.type == MapObjectType.creature) {
        final c = obj as Creature;
        if (c.isExpired || !c.isWild) return false;
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
