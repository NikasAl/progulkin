# Анализ архитектуры Flutter проекта "Прогулкин"

**Дата анализа:** 2026-04-04
**Дата обновления:** 2026-04-04 (после рефакторинга)

## 1. Структура проекта

```
lib/
├── main.dart                      # Точка входа, инициализация провайдеров
├── config/
│   ├── app_config.dart           # Конфигурация приложения
│   └── constants.dart            # Константы
├── models/
│   ├── walk.dart                 # Модель прогулки
│   ├── walk_point.dart           # Точка GPS маршрута
│   ├── distance_source.dart      # Источник расстояния
│   ├── contact_profile.dart      # Профиль контакта
│   ├── p2p_message.dart          # P2P сообщение
│   └── map_objects/              # Объекты карты
│       ├── map_object.dart       # Базовый класс
│       ├── map_objects.dart      # Фабрика объектов
│       ├── trash_monster.dart    # Мусорный монстр
│       ├── secret_message.dart   # Секретное сообщение
│       ├── creature.dart         # Существо
│       ├── interest_note.dart    # Заметка
│       ├── reminder_character.dart # Напоминалка
│       └── foraging_spot.dart    # Место сбора
├── providers/
│   ├── walk_provider.dart        # Управление прогулками
│   ├── pedometer_provider.dart   # Подсчёт шагов
│   ├── map_object_provider.dart  # Объекты карты (БОЛЬШОЙ!)
│   ├── chat_provider.dart        # P2P чаты
│   └── theme_provider.dart       # Тема приложения
├── services/
│   ├── location_service.dart     # GPS трекинг с фильтрацией
│   ├── pedometer_service.dart    # Шагомер (акселерометр)
│   ├── storage_service.dart      # Хранение прогулок (SharedPreferences)
│   ├── sync_service.dart         # Синхронизация через ZIP
│   ├── creature_service.dart     # Спавн существ
│   ├── user_id_service.dart      # ID пользователя
│   └── p2p/
│       ├── p2p_service.dart      # P2P сервис
│       ├── map_object_storage.dart # SQLite хранилище
│       ├── signaling_client.dart  # Сигнальный сервер
│       └── ...
├── screens/
│   ├── home_screen.dart          # Главный экран (~1100 строк!)
│   ├── settings_screen.dart      # Настройки (~1050 строк!)
│   └── ...
└── widgets/
    ├── map_objects_layer.dart    # Слой объектов на карте
    ├── object_details_sheet.dart # Детали объекта (~1100 строк!)
    └── ...
```

---

## 2. Провайдеры и состояние

### WalkProvider (~380 строк)
**Ответственность:** Управление прогулками, GPS трекинг, статистика

**Проблемы:**
- ❌ **Нарушение SRP** - управляет и прогулками, и настройками расстояния
- ❌ Создает экземпляры сервисов напрямую: `LocationService()`, `StorageService()`, `PedometerService()`

```dart
// walk_provider.dart:12-14
final LocationService _locationService = LocationService();
final StorageService _storageService = StorageService();
final PedometerService _pedometerService = PedometerService();
```

### MapObjectProvider (~1180 строк!) 
**Ответственность:** ВСЁ - объекты карты, P2P, существа, уведомления, модерация

**КРИТИЧЕСКИЕ ПРОБЛЕМЫ:**
- ❌ **God Object** - 1180 строк кода!
- ❌ Управляет 5+ сервисами напрямую
- ❌ Содержит бизнес-логику спавна существ, модерации, уведомлений

```dart
// map_object_provider.dart:12-18
final MapObjectStorage _storage = MapObjectStorage();
final P2PService _p2pService = P2PService();
final MapObjectExportService _exportService = MapObjectExportService();
final Uuid _uuid = const Uuid();
final CreatureService _creatureService = CreatureService();
final InterestNotificationService _notificationService = InterestNotificationService();
```

### PedometerProvider (~120 строк)
✅ **Хороший пример** - фокусированная ответственность

### ThemeProvider (~80 строк)
✅ **Хороший пример** - минимальный, фокусированный

---

## 3. Сервисы

### LocationService (~580 строк)
**Ответственность:** GPS трекинг с продвинутой фильтрацией

**Плюсы:**
- ✅ Singleton паттерн корректен
- ✅ Продвинутая фильтрация GPS данных
- ✅ Обнаружение неподвижности

**Проблемы:**
- ⚠️ Настройки фильтрации изменяемые извне (side effects)

### PedometerService (~410 строк)
**Ответственность:** Подсчёт шагов через системный датчик или акселерометр

**Плюсы:**
- ✅ Fallback на акселерометр при недоступности системного шагомера
- ✅ Настраиваемая чувствительность

### MapObjectStorage (~780 строк)
**Ответственность:** SQLite хранилище объектов

**Проблемы:**
- ❌ **God Service** - управляет объектами, фото, сообщениями, уведомлениями, профилями
- ❌ Нет разделения на репозитории

### P2PService (~340 строк)
**Ответственность:** P2P синхронизация

**Плюсы:**
- ✅ Чистая архитектура с отдельными компонентами (SignalingClient, SyncProtocol)
- ✅ Хорошая обработка состояний

---

## 4. Модели данных

### MapObject (базовый класс)
✅ **Хороший дизайн:**
- Полиморфизм через фабрику
- Поддержка soft delete
- Версионирование для синхронизации
- Geohash для зонной синхронизации

### Walk
✅ **Хороший дизайн:**
- Поддержка разных источников расстояния
- Статистика объектов карты

### Иерархия MapObjects
✅ **Хороший дизайн:**
```
MapObject (abstract)
├── TrashMonster    - с auto-classification
├── SecretMessage   - с геолокационным_unlock
├── Creature        - с RPG характеристиками
├── InterestNote    - с фото и интересами
├── ReminderCharacter - с триггерами
└── ForagingSpot    - с сезонностью
```

---

## 5. Экраны

### HomeScreen (~1100 строк!)
**КРИТИЧЕСКИЕ ПРОБЛЕМЫ:**
- ❌ **God Widget** - 1100 строк!
- ❌ Содержит бизнес-логику (спавн существ, обработка объектов)
- ❌ Прямой доступ к сервисам из виджета

```dart
// home_screen.dart:38-42
final LocationService _locationService = LocationService();
final UserIdService _userIdService = UserIdService();
final TileCacheService _tileCacheService = TileCacheService();
final ObjectActionService _actionService = ObjectActionService();
```

### SettingsScreen (~1050 строк!)
**Проблемы:**
- ❌ Слишком большой экран
- ⚠️ Прямой доступ к сервисам для изменения настроек

---

## 6. Виджеты

### ObjectDetailsSheet (~1100 строк!)
**Проблемы:**
- ❌ **God Widget**
- ❌ Содержит логику загрузки фото и модерации

### MapObjectsLayer (~650 строк)
**Плюсы:**
- ✅ Переиспользуемый компонент
- ⚠️ Содержит логику рендеринга для каждого типа объекта

---

## 7. Проблемы архитектуры

### 🔴 КРИТИЧЕСКИЕ

#### 1. God Objects
| Компонент | Строки | Проблема |
|-----------|--------|----------|
| MapObjectProvider | ~1180 | Управляет всем |
| HomeScreen | ~1100 | UI + бизнес-логика |
| ObjectDetailsSheet | ~1100 | UI + логика модерации |
| SettingsScreen | ~1050 | UI + логика настроек |

#### 2. Нарушение Dependency Inversion
```dart
// Все провайдеры создают сервисы напрямую:
final LocationService _locationService = LocationService();
final StorageService _storageService = StorageService();
// Должно быть через DI/конструктор
```

#### 3. Нарушение Single Responsibility Principle
- `MapObjectProvider` делает слишком много:
  - Управление объектами
  - P2P синхронизация
  - Спавн существ
  - Модерация фото
  - Уведомления
  - Профили контактов

#### 4. Сильная связанность (Tight Coupling)
```dart
// home_screen.dart напрямую зависит от сервисов
final LocationService _locationService = LocationService();
final UserIdService _userIdService = UserIdService();
// Вместо использования провайдеров или DI
```

### 🟡 СРЕДНИЕ

#### 5. Дублирование кода
- Функция `calculateDistance` определена в `map_object.dart` и дублируется в `walk.dart` (как `_haversineDistance`)

#### 6. Отсутствие абстракций для сервисов
- Нет интерфейсов для сервисов → невозможно тестировать с моками

#### 7. Проблемы с управлением состоянием
- `_currentLocation` дублируется в HomeScreen и MapObjectProvider
- `_routePoints` в HomeScreen дублирует данные из WalkProvider

### 🟢 МИНОРНЫЕ

#### 8. Magic Numbers
```dart
// map_object_provider.dart
return distance <= 500; // 500 метров - magic number

// catchCreature
return distance <= 25; // 25 метров - magic number
```

#### 9. Глобальный NavigatorKey
```dart
// main.dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
```

---

## 8. Рекомендации по рефакторингу

### Приоритет 1: Разделение MapObjectProvider

```dart
// Было:
class MapObjectProvider extends ChangeNotifier {
  final MapObjectStorage _storage = MapObjectStorage();
  final P2PService _p2pService = P2PService();
  final CreatureService _creatureService = CreatureService();
  // ... ещё 5 сервисов
}

// Стало:
class MapObjectProvider extends ChangeNotifier {
  final MapObjectRepository _repository;
  final P2PManager _p2pManager;
  // Только координация
}

// Вынести в отдельные провайдеры:
class CreatureProvider { ... }
class NotificationProvider { ... }
class ModerationProvider { ... }
```

### Приоритет 2: Внедрение Dependency Injection

```dart
// main.dart
void main() async {
  final getIt = GetIt.instance;
  
  // Регистрация сервисов
  getIt.registerSingleton<LocationService>(LocationService());
  getIt.registerSingleton<StorageService>(StorageService());
  getIt.registerSingleton<MapObjectStorage>(MapObjectStorage());
  
  // Провайдеры получают зависимости через конструктор
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => WalkProvider(
            locationService: getIt<LocationService>(),
            storageService: getIt<StorageService>(),
          ),
        ),
        // ...
      ],
    ),
  );
}

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

### Приоритет 3: Разделение экранов

```dart
// home_screen.dart - разделить на:

// home/
//   home_screen.dart          (~200 строк - только структура)
//   home_controller.dart      (~200 строк - логика)
//   components/
//     map_widget.dart
//     top_panel.dart
//     bottom_controls.dart
//     creature_spawner.dart
```

### Приоритет 4: Вынести общую логику

```dart
// utils/geo_utils.dart
double calculateDistance(double lat1, double lon1, double lat2, double lon2);

// utils/format_utils.dart
String formatDuration(Duration d);
String formatDistance(double meters);
```

### Приоритет 5: Создать репозитории

```dart
// repositories/
//   map_object_repository.dart
//   walk_repository.dart
//   message_repository.dart
//   notification_repository.dart

abstract class MapObjectRepository {
  Future<List<MapObject>> getAll();
  Future<void> save(MapObject object);
  Future<void> delete(String id);
  Stream<List<MapObject>> watch();
}

class SqliteMapObjectRepository implements MapObjectRepository {
  final Database _db;
  // ...
}
```

### Приоритет 6: Добавить абстракции сервисов

```dart
abstract class LocationServiceBase {
  Stream<WalkPoint> get positionStream;
  Future<bool> checkPermission();
  Future<WalkPoint?> getCurrentPosition();
  Future<void> startTracking();
  void stopTracking();
}

// Теперь можно создавать моки для тестов:
class MockLocationService implements LocationServiceBase { ... }
```

---

## 9. Итоговая оценка

| Критерий | Оценка | Комментарий |
|----------|--------|-------------|
| **SOLID - SRP** | 🔴 2/10 | Много God Objects |
| **SOLID - OCP** | 🟡 5/10 | Расширяемость через наследование, но не через композицию |
| **SOLID - LSP** | 🟢 8/10 | Модели хорошо спроектированы |
| **SOLID - ISP** | 🟡 5/10 | Некоторые провайдеры имеют слишком много методов |
| **SOLID - DIP** | 🔴 2/10 | Прямое создание зависимостей |
| **Тестируемость** | 🔴 3/10 | Нет DI, нет интерфейсов |
| **Поддерживаемость** | 🟡 5/10 | Код читаемый, но сложный для изменений |
| **Масштабируемость** | 🟡 5/10 | Функционально, но нужен рефакторинг |

---

## 10. План рефакторинга (рекомендуемый порядок)

### Фаза 1: Основы (2-3 недели)
1. **Неделя 1:** Внедрить DI (GetIt) + создать интерфейсы сервисов
2. **Неделя 2:** Разделить `MapObjectProvider` на 3-4 провайдера
3. **Неделя 3:** Разделить `HomeScreen` на компоненты

### Фаза 2: Улучшения (2-3 недели)
4. **Неделя 4:** Вынести репозитории, создать абстракции
5. **Неделя 5:** Добавить unit-тесты для критической логики
6. **Неделя 6:** Рефакторинг утилит и констант

### Фаза 3: Оптимизация (1-2 недели)
7. Устранить дублирование состояния
8. Добавить интеграционные тесты
9. Документировать архитектуру

---

## 11. Детальный план разделения MapObjectProvider

### Текущее состояние (~1180 строк)
```
MapObjectProvider
├── Управление объектами (CRUD)
├── P2P синхронизация
├── Спавн существ
├── Модерация фото
├── Уведомления
├── Профили контактов
├── Интересы к заметкам
└── Экспорт/импорт
```

### Предлагаемое разделение
```
MapObjectProvider (~300 строк)
├── Координация
├── Фильтрация объектов
└── Делегирование специализированным провайдерам

CreatureProvider (~200 строк)
├── Спавн существ
├── Поимка существ
└── Коллекция пользователя

NotificationProvider (~150 строк)
├── Уведомления о интересах
├── Напоминания
└── Статус прочтения

ModerationProvider (~150 строк)
├── Голосование за фото
├── Подтверждение/опровержение объектов
└── Статистика модерации

P2PProvider (~200 строк)
├── Синхронизация
├── Статус соединения
└── Обмен объектами
```

---

## 12. Выгоды от рефакторинга

### Тестируемость
- Можно писать unit-тесты для каждого провайдера изолированно
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

### Производительность разработки
- Меньше времени на понимание кода
- Быстрее onboarding новых разработчиков
- Меньше регрессионных багов

---

## 13. Выполненный рефакторинг (2026-04-04)

### Исправленные проблемы

#### Критические исправления (bugs)
1. **Расчёт расстояния** - исправлены критические ошибки в функциях `_cos()` и `_sqrt()` в `map_object.dart` и `object_action_service.dart`. Кастомные реализации возвращали неверные значения (например, `_sqrt(x)` возвращал `x` вместо `√x`). Заменены на `dart:math`.

2. **Синхронизация существ** - исправлена ошибка, при которой существа оставались на карте после завершения прогулки. Добавлены методы очистки в `MapObjectProvider`.

#### Устранение warnings и deprecation
1. **Unused code** - удалены неиспользуемый геттер `_accumulatedPauseDuration` и неиспользуемый импорт `dart:io`.

2. **withOpacity → withValues** - заменено 94 использования устаревшего метода `Color.withOpacity()` на новый `Color.withValues(alpha: ...)`.

3. **print → debugPrint** - заменено 41 использование `print()` на `debugPrint()` в сервисах (`location_service.dart`, `pedometer_service.dart`, `storage_service.dart`).

4. **BuildContext async gaps** - добавлены проверки `mounted` перед использованием `context` после `await` в 5 местах.

#### Style improvements
- Удалены неиспользуемые импорты (`dart:typed_data`, `flutter/services.dart`)
- Использован оператор `??=` вместо `if (x == null) { x = ... }`
- Очищены minor style issues

### Статистика до/после

| Метрика | До | После |
|---------|-----|-------|
| Analyzer warnings | 2 | 0 |
| Analyzer info issues | 203 | 56 |
| Deprecated API usage | ~95 | 2 (Radio widget) |
| print() calls | 41 | 0 |

### Оставшиеся info-level issues (56)

| Тип | Количество | Приоритет |
|-----|------------|-----------|
| prefer_const_constructors | 26 | Low |
| unnecessary_brace_in_string_interps | 10 | Low |
| prefer_final_locals | 8 | Low |
| prefer_final_fields | 5 | Low |
| deprecated_member_use (Radio) | 2 | Medium |
| dangling_library_doc_comments | 2 | Low |
| Other | 3 | Low |

### Рекомендации по дальнейшему рефакторингу

#### Приоритет 1: Radio widget deprecation
Заменить `RadioListTile` с deprecated свойствами `groupValue`/`onChanged` на новый API `RadioGroup` (Flutter 3.32+).

#### Приоритет 2: God Objects (по оригинальному плану)
Разделение `MapObjectProvider`, `HomeScreen`, `ObjectDetailsSheet` на более мелкие компоненты.

#### Приоритет 3: Dependency Injection
Внедрение DI контейнера (GetIt) для улучшения тестируемости.

### Коммиты рефакторинга
1. `e20090c` - Fix creature synchronization bugs
2. `c9a3ce6` - Fix distance calculation bugs  
3. `cae9db7` - Fix analyzer warnings and async context issues
4. `b0f9648` - Replace deprecated withOpacity with withValues
5. `25b9cea` - Replace print with debugPrint in services
6. `6744634` - Fix style issues and remove unused imports
