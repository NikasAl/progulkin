import 'package:get_it/get_it.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../services/pedometer_service.dart';
import '../services/tile_cache_service.dart';
import '../services/tile_color_habitat_service.dart';
import '../services/habitat_cache_service.dart';
import '../services/habitat_service.dart';
import '../services/creature_service.dart';
import '../services/user_id_service.dart';
import '../services/object_action_service.dart';
import '../services/sync_service.dart';
import '../services/incoming_file_service.dart';
import '../services/interest_notification_service.dart';
import '../services/map_object_export_service.dart';
import '../services/photo_compression_service.dart';
import '../services/notification_settings_service.dart';
import '../services/p2p/p2p_service.dart';
import '../services/p2p/map_object_storage.dart';

/// Глобальный экземпляр GetIt
final GetIt getIt = GetIt.instance;

/// Флаг инициализации
bool _isInitialized = false;

/// Инициализация Dependency Injection
///
/// Регистрирует все сервисы приложения как singletons.
/// Должна вызываться в main() до runApp().
Future<void> setupDependencies() async {
  if (_isInitialized) return;
  _isInitialized = true;

  // === Основные сервисы ===
  // Эти сервисы не имеют зависимостей от других сервисов

  getIt.registerSingleton<UserIdService>(UserIdService());
  getIt.registerSingleton<StorageService>(StorageService());
  getIt.registerSingleton<LocationService>(LocationService());
  getIt.registerSingleton<PedometerService>(PedometerService());
  getIt.registerSingleton<PhotoCompressionService>(PhotoCompressionService());
  getIt.registerSingleton<ObjectActionService>(ObjectActionService());

  // === Сервисы с зависимостями ===
  // Порядок важен - сначала регистрируем зависимости

  // HabitatCacheService не имеет зависимостей
  getIt.registerSingleton<HabitatCacheService>(HabitatCacheService());

  // HabitatService зависит от HabitatCacheService
  getIt.registerSingleton<HabitatService>(HabitatService());

  // TileColorHabitatService зависит от HabitatCacheService
  getIt.registerSingleton<TileColorHabitatService>(TileColorHabitatService());

  // TileCacheService зависит от HabitatCacheService
  getIt.registerSingleton<TileCacheService>(TileCacheService());

  // CreatureService зависит от TileColorHabitatService
  getIt.registerSingleton<CreatureService>(CreatureService());

  // === P2P сервисы ===

  // MapObjectStorage - основное хранилище
  getIt.registerSingleton<MapObjectStorage>(MapObjectStorage());

  // SyncService зависит от MapObjectStorage
  getIt.registerSingleton<SyncService>(SyncService());

  // IncomingFileService зависит от SyncService
  getIt.registerSingleton<IncomingFileService>(IncomingFileService());

  // P2PService зависит от MapObjectStorage
  getIt.registerSingleton<P2PService>(P2PService());

  // === Сервисы уведомлений и экспорта ===

  getIt.registerSingleton<NotificationSettingsService>(NotificationSettingsService());
  getIt.registerSingleton<InterestNotificationService>(InterestNotificationService());
  getIt.registerSingleton<MapObjectExportService>(MapObjectExportService());
}

/// Проверка инициализации DI
bool get isDependenciesInitialized => _isInitialized;

/// Сброс зависимостей (только для тестов)
void resetDependencies() {
  if (_isInitialized) {
    getIt.reset();
    _isInitialized = false;
  }
}
