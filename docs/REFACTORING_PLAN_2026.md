# План рефакторинга Прогулкин - 2026

**Дата создания:** 2026-04-15
**Статус:** Актуальный план

---

## 1. Текущее состояние архитектуры

### 1.1. Размеры основных файлов

| Файл | Строк | Статус | Проблема |
|------|-------|--------|----------|
| `home_screen.dart` | 1415 | ⏳ Частично разделён | God Widget |
| `settings_screen.dart` | 1217 | ⏳ Не разделён | God Widget |
| `object_details_sheet.dart` | 1138 | ⏳ Не разделён | God Widget |
| `add_object_screen.dart` | 1021 | ⏳ Не разделён | Сложная логика |
| `history_screen.dart` | 803 | ⚠️ Приемлемо | Можно оптимизировать |
| `map_object_storage.dart` | 783 | ⏳ God Service | Много ответственностей |
| `map_objects_layer.dart` | 777 | ✅ Исправлено | Баг с артефактами |
| `storage_screen.dart` | 770 | ⚠️ Приемлемо | - |
| `map_object_provider.dart` | 668 | ✅ Рефакторинг завершён | Facade pattern |

### 1.2. Выполненные улучшения

✅ **MapObjectProvider → Facade + 8 провайдеров**
- CreatureProvider (267 строк) - спавн/поимка существ
- P2PProvider (119 строк) - синхронизация
- ModerationProvider (103 строки) - модерация
- NotificationProvider (60 строк) - уведомления
- ContactProvider (99 строк) - контакты
- InterestProvider (109 строк) - интересы
- ReminderProvider (80 строк) - напоминания
- ForagingProvider (81 строка) - места сбора

✅ **Исправлены warnings и deprecated API**
- withOpacity → withValues (94 замены)
- print → debugPrint (41 замена)
- Добавлены проверки mounted

✅ **Исправлен баг с артефактами маркеров**
- Добавлены ValueKey для Marker и _MarkerWidget

✅ **Частичное разделение HomeScreen**
- Создана папка `lib/screens/home/`
- Вынесены: steps_panel.dart, walk_stats_panel.dart, home_components.dart, bottom_controls.dart

---

## 2. Проблемы архитектуры

### 2.1. Критические (P0)

#### 2.1.1. God Widgets
**Проблема:** Экраны содержат UI, бизнес-логику и прямое обращение к сервисам.

```dart
// home_screen.dart - прямое создание сервисов
final LocationService _locationService = LocationService();
final UserIdService _userIdService = UserIdService();
final TileCacheService _tileCacheService = TileCacheService();
final ObjectActionService _actionService = ObjectActionService();
```

**Решение:** Вынести логику в контроллеры/провайдеры, использовать DI.

#### 2.1.2. God Service - MapObjectStorage
**Проблема:** 783 строки, управляет:
- Объектами карты (CRUD)
- Фото
- Сообщениями
- Уведомлениями
- Профилями контактов

**Решение:** Разделить на репозитории.

### 2.2. Средние (P1)

#### 2.2.1. Отсутствие Dependency Injection
**Проблема:** Сервисы создаются напрямую в провайдерах и виджетах.

**Решение:** Внедрить GetIt для управления зависимостями.

#### 2.2.2. Дублирование кода
**Проблема:** `calculateDistance` определён в `map_object.dart` и дублируется как `_haversineDistance` в `walk.dart`.

**Решение:** Вынести в `lib/utils/geo_utils.dart`.

#### 2.2.3. Отсутствие абстракций сервисов
**Проблема:** Нет интерфейсов → невозможно тестировать с моками.

**Решение:** Создать абстрактные классы для сервисов.

### 2.3. Минорные (P2)

- Magic numbers в коде (радиусы, таймауты)
- Глобальный NavigatorKey
- Дублирование состояния (_currentLocation в HomeScreen и MapObjectProvider)

---

## 3. План рефакторинга

### Фаза 1: Dependency Injection (1-2 дня)

#### 1.1. Внедрение GetIt
```dart
// lib/main.dart
final getIt = GetIt.instance;

void setupDependencies() {
  // Singleton сервисы
  getIt.registerSingleton<LocationService>(LocationService());
  getIt.registerSingleton<StorageService>(StorageService());
  getIt.registerSingleton<MapObjectStorage>(MapObjectStorage());
  getIt.registerSingleton<UserIdService>(UserIdService());
  getIt.registerSingleton<TileCacheService>(TileCacheService());
  getIt.registerSingleton<ObjectActionService>(ObjectActionService());

  // Провайдеры получают зависимости через конструктор
}

// Провайдер
class WalkProvider extends ChangeNotifier {
  final LocationService _locationService;
  final StorageService _storageService;

  WalkProvider({
    required LocationService locationService,
    required StorageService storageService,
  }) : _locationService = locationService,
       _storageService = storageService;
}
```

**Затронутые файлы:**
- `lib/main.dart` - регистрация сервисов
- Все провайдеры - инъекция через конструктор
- Все экраны - получение сервисов через DI

**Оценка:** 1-2 дня

---

### Фаза 2: Разделение God Widgets (3-5 дней)

#### 2.1. HomeScreen (1415 → ~300 строк)

**Структура:**
```
lib/screens/home/
├── home_screen.dart           (~300 строк - только структура)
├── home_controller.dart       (~200 строк - логика)
├── home_map_widget.dart       (~150 строк - карта)
├── home_top_panel.dart        (~100 строк - статистика)
├── home_bottom_controls.dart  (~100 строк - кнопки)
├── steps_panel.dart           (существует)
├── walk_stats_panel.dart      (существует)
├── home_components.dart       (существует)
└── bottom_controls.dart       (существует)
```

**Вынести:**
1. `_buildMap()` → `HomeMapWidget`
2. `_buildTopPanel()` → `HomeTopPanel` (уже частично)
3. `_buildBottomControls()` → `HomeBottomControls` (уже частично)
4. `_showObjectDetails()` → `ObjectDetailsController`
5. `_startWalk()`, `_stopWalk()`, `_spawnCreatures()` → `HomeController`

#### 2.2. SettingsScreen (1217 → ~200 строк)

**Структура:**
```
lib/screens/settings/
├── settings_screen.dart       (~200 строк - структура)
├── sections/
│   ├── profile_section.dart   (~150 строк)
│   ├── walk_settings_section.dart (~150 строк)
│   ├── data_section.dart      (~150 строк)
│   ├── pedometer_section.dart (~150 строк)
│   ├── about_section.dart     (~100 строк)
│   └── developer_section.dart (~100 строк)
└── settings_controller.dart   (~100 строк - логика)
```

#### 2.3. ObjectDetailsSheet (1138 → ~200 строк)

**Структура:**
```
lib/widgets/object_details/
├── object_details_sheet.dart  (~200 строк - структура)
├── details/
│   ├── trash_monster_details.dart  (~150 строк)
│   ├── creature_details.dart       (~150 строк)
│   ├── secret_message_details.dart (~100 строк)
│   ├── interest_note_details.dart  (~150 строк)
│   ├── reminder_details.dart       (~100 строк)
│   └── foraging_details.dart       (~100 строк)
├── photo_gallery_widget.dart  (~100 строк)
└── object_action_button.dart  (~80 строк)
```

**Оценка:** 3-5 дней

---

### Фаза 3: Разделение MapObjectStorage (2-3 дня)

#### 3.1. Создать репозитории
```
lib/repositories/
├── map_object_repository.dart      (интерфейс)
├── sqlite_map_object_repository.dart
├── photo_repository.dart           (интерфейс)
├── sqlite_photo_repository.dart
├── message_repository.dart         (интерфейс)
├── sqlite_message_repository.dart
├── contact_repository.dart         (интерфейс)
└── sqlite_contact_repository.dart
```

#### 3.2. Обновить MapObjectStorage
```dart
// Было: God Service с 783 строками
// Стало: Координатор репозиториев (~200 строк)
class MapObjectStorage {
  final MapObjectRepository _objectRepo;
  final PhotoRepository _photoRepo;
  final MessageRepository _messageRepo;
  final ContactRepository _contactRepo;

  MapObjectStorage({
    required MapObjectRepository objectRepo,
    required PhotoRepository photoRepo,
    // ...
  });

  // Делегирование репозиториям
  Future<List<MapObject>> getAllObjects() => _objectRepo.getAll();
  Future<void> savePhoto(Photo photo) => _photoRepo.save(photo);
  // ...
}
```

**Оценка:** 2-3 дня

---

### Фаза 4: Утилиты и абстракции (1 день)

#### 4.1. Вынести общую логику
```dart
// lib/utils/geo_utils.dart
double calculateDistance(double lat1, double lon1, double lat2, double lon2);
LatLng calculateMidpoint(List<LatLng> points);
double calculateBearing(LatLng from, LatLng to);

// lib/utils/format_utils.dart
String formatDuration(Duration d);
String formatDistance(double meters);
String formatSpeed(double metersPerSecond);
```

#### 4.2. Абстракции сервисов
```dart
// lib/services/base/location_service_base.dart
abstract class LocationServiceBase {
  Stream<WalkPoint> get positionStream;
  Future<bool> checkPermission();
  Future<WalkPoint?> getCurrentPosition();
  Future<void> startTracking();
  void stopTracking();
}

// lib/services/base/storage_service_base.dart
abstract class StorageServiceBase {
  Future<void> saveWalk(Walk walk);
  Future<List<Walk>> loadWalks();
  // ...
}

// Теперь можно создавать моки:
class MockLocationService implements LocationServiceBase { ... }
```

**Оценка:** 1 день

---

## 4. Итоговая структура проекта

```
lib/
├── main.dart                      # Точка входа, DI setup
├── config/
│   ├── app_config.dart
│   ├── constants.dart
│   └── version.dart
├── models/                        # (без изменений)
├── providers/
│   ├── walk_provider.dart         # DI через конструктор
│   ├── map_object_provider.dart   # Facade
│   ├── creature_provider.dart
│   ├── p2p_provider.dart
│   └── ... (остальные)
├── repositories/                  # НОВОЕ
│   ├── map_object_repository.dart
│   ├── photo_repository.dart
│   ├── message_repository.dart
│   └── contact_repository.dart
├── services/
│   ├── base/                      # НОВОЕ - абстракции
│   │   ├── location_service_base.dart
│   │   └── storage_service_base.dart
│   ├── location_service.dart
│   ├── storage_service.dart
│   └── ...
├── screens/
│   ├── home/
│   │   ├── home_screen.dart       # ~300 строк
│   │   ├── home_controller.dart
│   │   ├── home_map_widget.dart
│   │   └── ...
│   ├── settings/
│   │   ├── settings_screen.dart   # ~200 строк
│   │   └── sections/
│   └── ...
├── widgets/
│   ├── object_details/
│   │   ├── object_details_sheet.dart  # ~200 строк
│   │   └── details/
│   └── ...
└── utils/                         # НОВОЕ
    ├── geo_utils.dart
    └── format_utils.dart
```

---

## 5. Оценка времени

| Фаза | Описание | Время | Приоритет |
|------|----------|-------|-----------|
| 1 | Dependency Injection (GetIt) | 1-2 дня | P0 |
| 2.1 | Разделение HomeScreen | 1-2 дня | P1 |
| 2.2 | Разделение SettingsScreen | 1 день | P1 |
| 2.3 | Разделение ObjectDetailsSheet | 1-2 дня | P1 |
| 3 | Разделение MapObjectStorage | 2-3 дня | P1 |
| 4 | Утилиты и абстракции | 1 день | P2 |
| **Итого** | | **7-11 дней** | |

---

## 6. Выгоды от рефакторинга

### Тестируемость
- Unit-тесты для каждого провайдера изолированно
- Моки для сервисов через интерфейсы
- Интеграционные тесты без реальных зависимостей

### Поддерживаемость
- Каждый файл < 300 строк
- Чёткая ответственность каждого компонента
- Легче находить и исправлять баги

### Масштабируемость
- Легко добавлять новые типы объектов
- Новые функции не ломают существующий код
- Командная разработка без конфликтов

### Читаемость кода
- Меньше времени на понимание кода
- Быстрее onboarding новых разработчиков
- Меньше регрессионных багов

---

## 7. Метрики успеха

| Метрика | До | После |
|---------|-----|-------|
| Файлов > 1000 строк | 4 | 0 |
| Файлов > 500 строк | 8 | 2-3 |
| Средний размер экрана | 800 | 250 |
| DI覆盖率 | 0% | 100% |
| Unit test coverage | 0% | 60%+ |

---

## 8. Риски и митигация

### Риск: Регрессионные баги при разделении
**Митигация:**
- Добавить widget tests перед рефакторингом
- Рефакторинг по одному экрану за раз
- Тестирование после каждого этапа

### Риск: Увеличение количества файлов
**Митигация:**
- Логичная структура папок
- Чёткое именование файлов
- Индексные файлы для экспорта

### Риск: Время на рефакторинг
**Митигация:**
- Приоритизация по P0/P1/P2
- Возможность остановиться после любой фазы
- Инкрементальный подход

---

*Документ создан: 2026-04-15*
