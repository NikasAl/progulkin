import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'di/service_locator.dart';
import 'providers/map_object_provider.dart';
import 'providers/creature_provider.dart';
import 'providers/p2p_provider.dart';
import 'providers/moderation_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/interest_provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/foraging_provider.dart';
import 'providers/walk_provider.dart';
import 'providers/pedometer_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/route_provider.dart';
import 'services/incoming_file_service.dart';
import 'services/sync_service.dart';
import 'services/tile_color_habitat_service.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'services/pedometer_service.dart';
import 'services/p2p/map_object_storage.dart';
import 'screens/home_screen.dart';
import 'models/map_objects/map_objects.dart'; // Инициализация фабрики объектов

/// Глобальный ключ навигатора для показа диалогов из сервиса
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Dependency Injection
  await setupDependencies();

  // Инициализация фабрики объектов карты (обязательно до использования)
  initMapObjectFactory();

  // Инициализация локали для форматирования дат
  await initializeDateFormatting('ru_RU', null);

  // Инициализация сервиса определения среды обитания (загрузка кэша)
  await getIt<TileColorHabitatService>().init();

  // Инициализация сервиса входящих файлов
  getIt<IncomingFileService>().init();

  // Настраиваем callback для показа результата импорта
  getIt<IncomingFileService>().onFileReceived = (result) {
    _showImportResult(result);
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProgulkinApp());
}

/// Показать результат импорта файла
void _showImportResult(ZipImportResult result) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.error,
            color: result.success ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(result.success ? 'Импорт завершён' : 'Ошибка импорта'),
        ],
      ),
      content: Text(
          result.success ? result.summary : (result.error ?? 'Неизвестная ошибка')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class ProgulkinApp extends StatefulWidget {
  const ProgulkinApp({super.key});

  @override
  State<ProgulkinApp> createState() => _ProgulkinAppState();
}

class _ProgulkinAppState extends State<ProgulkinApp> {
  late final MapObjectProvider _mapObjectProvider;
  late final CreatureProvider _creatureProvider;
  late final P2PProvider _p2pProvider;
  late final ModerationProvider _moderationProvider;
  late final NotificationProvider _notificationProvider;
  late final ContactProvider _contactProvider;
  late final InterestProvider _interestProvider;
  late final ReminderProvider _reminderProvider;
  late final ForagingProvider _foragingProvider;

  bool _initialized = false;
  bool _providersCreated = false;

  @override
  void initState() {
    super.initState();
    _createProviders();
  }

  void _createProviders() {
    // Получаем хранилище из DI
    final storage = getIt<MapObjectStorage>();

    // Создаём специализированные провайдеры с инъекцией зависимостей
    _creatureProvider = CreatureProvider(storage: storage);
    _p2pProvider = P2PProvider();
    _moderationProvider = ModerationProvider(storage: storage);
    _notificationProvider = NotificationProvider();
    _contactProvider = ContactProvider(storage: storage);
    _interestProvider = InterestProvider(storage: storage);
    _reminderProvider = ReminderProvider(storage: storage);
    _foragingProvider = ForagingProvider(storage: storage);

    // Создаём MapObjectProvider (координатор/фасад)
    _mapObjectProvider = MapObjectProvider.withProviders(
      creatureProvider: _creatureProvider,
      p2pProvider: _p2pProvider,
      moderationProvider: _moderationProvider,
      notificationProvider: _notificationProvider,
      contactProvider: _contactProvider,
      interestProvider: _interestProvider,
      reminderProvider: _reminderProvider,
      foragingProvider: _foragingProvider,
    );

    // Настраиваем связи между провайдерами
    _wireProviders();

    // Подписываем специализированные провайдеры на изменения MapObjectProvider
    _mapObjectProvider.addListener(_onMapObjectsChanged);

    _providersCreated = true;
  }

  void _wireProviders() {
    // CreatureProvider callbacks
    _creatureProvider.broadcastUpdate = (object) async {
      await _p2pProvider.broadcastObject(object);
    };
    _creatureProvider.getAllObjects = () => _mapObjectProvider.allObjects;
    _creatureProvider.updateObjectInList = (id, updated) {
      _mapObjectProvider.updateObjectFromProvider(id, updated);
    };

    // P2PProvider callbacks
    _p2pProvider.onObjectReceived = (object) {
      _mapObjectProvider.onObjectReceivedFromP2P(object);
    };
    _p2pProvider.onSyncComplete = (result) {
      if (result.hasChanges) {
        _mapObjectProvider.reload();
      }
    };

    // ModerationProvider callbacks
    _moderationProvider.broadcastUpdate = (object) async {
      await _p2pProvider.broadcastObject(object);
    };
    _moderationProvider.updateObjectInList = (id, updated) {
      _mapObjectProvider.updateObjectFromProvider(id, updated);
    };
    _moderationProvider.updateNearbyObjects = () {
      _mapObjectProvider.refreshNearbyObjects();
    };

    // InterestProvider callbacks
    _interestProvider.broadcastUpdate = (object) async {
      await _p2pProvider.broadcastObject(object);
    };
    _interestProvider.updateObjectInList = (id, updated) {
      _mapObjectProvider.updateObjectFromProvider(id, updated);
    };
    _interestProvider.notifyAuthorAboutInterest = (
        {required noteId,
        required noteTitle,
        required authorId,
        required interestedUserId,
        required interestedUserName}) async {
      await _notificationProvider.notifyAuthorAboutInterest(
        noteId: noteId,
        noteTitle: noteTitle,
        authorId: authorId,
        interestedUserId: interestedUserId,
        interestedUserName: interestedUserName,
      );
    };

    // ReminderProvider callbacks
    _reminderProvider.broadcastUpdate = (object) async {
      await _p2pProvider.broadcastObject(object);
    };
    _reminderProvider.updateObjectInList = (id, updated) {
      _mapObjectProvider.updateObjectFromProvider(id, updated);
    };
    _reminderProvider.getAllObjects = () => _mapObjectProvider.allObjects;

    // ForagingProvider callbacks
    _foragingProvider.broadcastUpdate = (object) async {
      await _p2pProvider.broadcastObject(object);
    };
    _foragingProvider.updateObjectInList = (id, updated) {
      _mapObjectProvider.updateObjectFromProvider(id, updated);
    };
    _foragingProvider.getAllObjects = () => _mapObjectProvider.allObjects;
    _foragingProvider.getNearbyObjects = () => _mapObjectProvider.nearbyObjects;
  }

  /// Callback при изменении объектов в MapObjectProvider
  void _onMapObjectsChanged() {
    // Уведомляем специализированные провайдеры об изменениях
    _creatureProvider.notifyObjectsChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && _providersCreated) {
      _initialized = true;
      _initProviders();
    }
  }

  Future<void> _initProviders() async {
    // Инициализируем MapObjectProvider
    await _mapObjectProvider.init();

    if (!mounted) return;

    // Инициализируем NotificationProvider
    await _notificationProvider.init();

    if (!mounted) return;

    // Инициализируем P2PProvider
    await _p2pProvider.init(
      onNewObject: (object) {
        _mapObjectProvider.onObjectReceivedFromP2P(object);
      },
      onSync: (result) {
        if (result.hasChanges) {
          _mapObjectProvider.reload();
        }
      },
    );

    debugPrint('✅ Провайдеры инициализированы');
  }

  @override
  void dispose() {
    _mapObjectProvider.removeListener(_onMapObjectsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => WalkProvider(
          locationService: getIt<LocationService>(),
          storageService: getIt<StorageService>(),
          pedometerService: getIt<PedometerService>(),
        )),
        ChangeNotifierProvider(create: (_) => PedometerProvider(
          pedometerService: getIt<PedometerService>(),
        )),
        ChangeNotifierProvider.value(value: _mapObjectProvider),
        ChangeNotifierProvider.value(value: _creatureProvider),
        ChangeNotifierProvider.value(value: _p2pProvider),
        ChangeNotifierProvider.value(value: _moderationProvider),
        ChangeNotifierProvider.value(value: _notificationProvider),
        ChangeNotifierProvider.value(value: _contactProvider),
        ChangeNotifierProvider.value(value: _interestProvider),
        ChangeNotifierProvider.value(value: _reminderProvider),
        ChangeNotifierProvider.value(value: _foragingProvider),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => RouteProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Прогулкин',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF4CAF50),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                elevation: 4,
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF4CAF50),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeProvider.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
