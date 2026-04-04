# Анализ архитектуры Flutter проекта "Прогулкин"

**Дата анализа:** 2026-04-04
**Дата обновления:** 2026-04-04 (рефакторинг провайдеров завершён)

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
│   ├── map_object_provider.dart  # Фасад для объектов карты (668 строк)
│   ├── creature_provider.dart    # Существа
│   ├── p2p_provider.dart         # P2P синхронизация
│   ├── moderation_provider.dart  # Модерация
│   ├── notification_provider.dart# Уведомления
│   ├── contact_provider.dart     # Контакты
│   ├── interest_provider.dart    # Интересы
│   ├── reminder_provider.dart    # Напоминания
│   ├── foraging_provider.dart    # Места сбора
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

### MapObjectProvider (668 строк) ✅ РЕФАКТОРИНГ ЗАВЕРШЁН
**Ответственность:** Фасад для координации специализированных провайдеров

**До рефакторинга:**
- ❌ **God Object** - 1206 строк кода
- ❌ Управлял 5+ сервисами напрямую
- ❌ Содержал дублирующую бизнес-логику

**После рефакторинга:**
- ✅ **Facade Pattern** - чистое делегирование
- ✅ 668 строк (-45% от оригинала)
- ✅ Координирует 8 специализированных провайдеров
- ✅ Нет дублирования логики

```dart
// map_object_provider.dart - сейчас
class MapObjectProvider extends ChangeNotifier {
  // Специализированные провайдеры
  CreatureProvider? _creatureProvider;
  P2PProvider? _p2pProvider;
  ModerationProvider? _moderationProvider;
  // ... ещё 5 провайдеров
  
  // Только координация и делегирование
  Future<Creature> spawnCreature(...) async {
    return await _creatureProvider!.spawnCreature(...);
  }
}
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

#### 1. God Objects (статус после рефакторинга)
| Компонент | Было | Стало | Статус |
|-----------|------|-------|--------|
| MapObjectProvider | ~1206 | 668 | ✅ Исправлен (Facade) |
| HomeScreen | ~1100 | ~1100 | ⏳ В планах |
| ObjectDetailsSheet | ~1100 | ~1100 | ⏳ В планах |
| SettingsScreen | ~1050 | ~1050 | ⏳ В планах |

#### 2. Нарушение Dependency Inversion
```dart
// Все провайдеры создают сервисы напрямую:
final LocationService _locationService = LocationService();
final StorageService _storageService = StorageService();
// Должно быть через DI/конструктор
```

#### 3. Нарушение Single Responsibility Principle
- ~~`MapObjectProvider` делает слишком много~~ ✅ **ИСПРАВЛЕНО** - разделён на 8 провайдеров
- `HomeScreen` всё ещё содержит:
  - UI рендеринг
  - Бизнес-логику (частично вынесена в провайдеры)
  - Прямой доступ к сервисам

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

### Приоритет 1: Разделение MapObjectProvider ✅ ВЫПОЛНЕНО

```dart
// Было:
class MapObjectProvider extends ChangeNotifier {
  final MapObjectStorage _storage = MapObjectStorage();
  final P2PService _p2pService = P2PService();
  final CreatureService _creatureService = CreatureService();
  // ... ещё 5 сервисов
  // + fallback-реализации всей логики
}

// Стало (Facade Pattern):
class MapObjectProvider extends ChangeNotifier {
  // Специализированные провайдеры (инъектируются)
  CreatureProvider? _creatureProvider;
  P2PProvider? _p2pProvider;
  ModerationProvider? _moderationProvider;
  // ... ещё 5 провайдеров

  // Только координация и делегирование
  Future<Creature> spawnCreature(...) => _creatureProvider!.spawnCreature(...);
  Future<void> confirmObject(...) => _moderationProvider!.confirmObject(...);
}

// Вынесено в отдельные провайдеры:
class CreatureProvider { ... }    // 267 строк
class P2PProvider { ... }         // 119 строк
class ModerationProvider { ... }  // 103 строк
class NotificationProvider { ... }// 60 строк
class ContactProvider { ... }     // 99 строк
class InterestProvider { ... }    // 109 строк
class ReminderProvider { ... }    // 80 строк
class ForagingProvider { ... }    // 81 строк
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

| Критерий | До | После | Комментарий |
|----------|-----|-------|-------------|
| **SOLID - SRP** | 🔴 2/10 | 🟡 6/10 | MapObjectProvider исправлен, UI компоненты в планах |
| **SOLID - OCP** | 🟡 5/10 | 🟡 5/10 | Без изменений |
| **SOLID - LSP** | 🟢 8/10 | 🟢 8/10 | Модели хорошо спроектированы |
| **SOLID - ISP** | 🟡 5/10 | 🟢 7/10 | Провайдеры разделены на специализированные |
| **SOLID - DIP** | 🔴 2/10 | 🟡 4/10 | Частичное улучшение через callbacks |
| **Тестируемость** | 🔴 3/10 | 🟡 5/10 | Провайдеры можно тестировать изолированно |
| **Поддерживаемость** | 🟡 5/10 | 🟢 7/10 | Чёткое разделение ответственности |
| **Масштабируемость** | 🟡 5/10 | 🟢 7/10 | Легко добавлять новые функции |

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

## 11. Детальный план разделения MapObjectProvider ✅ ВЫПОЛНЕНО

### Было (~1206 строк)
```
MapObjectProvider (God Object)
├── Управление объектами (CRUD)
├── P2P синхронизация
├── Спавн существ
├── Модерация фото
├── Уведомления
├── Профили контактов
├── Интересы к заметкам
└── Экспорт/импорт
```

### Стало (Facade + 8 провайдеров)
```
MapObjectProvider (668 строк) - Facade
├── Координация провайдеров
├── Управление списками объектов
├── Фильтрация
├── Создание объектов (фабричные методы)
└── Делегирование →

    CreatureProvider (267 строк)
    ├── Спавн существ
    ├── Поимка существ
    └── Коллекция пользователя

    P2PProvider (119 строк)
    ├── Синхронизация
    ├── Статус соединения
    └── Обмен объектами

    ModerationProvider (103 строк)
    ├── Голосование за фото
    ├── Подтверждение/опровержение объектов
    └── Статистика модерации

    NotificationProvider (60 строк)
    ├── Уведомления о интересах
    └── Статус прочтения

    ContactProvider (99 строк)
    ├── Профили контактов
    └── Видимость контактов

    InterestProvider (109 строк)
    ├── Отметки "Интересно"
    └── Запросы контактов

    ReminderProvider (80 строк)
    ├── Создание напоминаний
    └── Управление активностью

    ForagingProvider (81 строк)
    ├── Места сбора
    └── Подтверждение мест
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
| Analyzer info issues | 203 | 37 |
| Deprecated API usage | ~95 | 0 |
| print() calls | 41 | 0 |

### Оставшиеся info-level issues (37)

| Тип | Количество | Приоритет |
|-----|------------|-----------|
| prefer_const_constructors | 26 | Low |
| prefer_final_locals | 8 | Low |
| Other | 3 | Low |

### Рекомендации по дальнейшему рефакторингу

#### Приоритет 1: Интеграция новых провайдеров
Заменить вызовы MapObjectProvider на специализированные провайдеры в UI компонентах.

#### Приоритет 2: Dependency Injection
Внедрение DI контейнера (GetIt) для улучшения тестируемости.

#### Приоритет 3: Разделение UI компонентов
Разделение `HomeScreen`, `ObjectDetailsSheet` на более мелкие виджеты.

### Выполненное разделение God Objects (MapObjectProvider)

**До:** 1 файл ~1206 строк, 10+ ответственностей, fallback-реализации

**После:** Facade + 8 специализированных провайдеров

| Провайдер | Строк | Ответственность |
|-----------|-------|----------------|
| **MapObjectProvider** | 668 | Фасад, координация, создание объектов |
| CreatureProvider | 267 | Спавн, поимка, коллекция существ |
| P2PProvider | 119 | P2P синхронизация |
| ModerationProvider | 103 | Модерация объектов и фото |
| NotificationProvider | 60 | Уведомления |
| ContactProvider | 99 | Профили контактов |
| InterestProvider | 109 | Интересы к заметкам |
| ReminderProvider | 80 | Напоминания |
| ForagingProvider | 81 | Места сбора |
| **ИТОГО** | **1586** | |

**Сравнение:**
- До (монолит): 1206 строк
- После (фасад + специализация): 1586 строк
- Добавлено: 380 строк (архитектурные улучшения)
- Удалено дублирования: 713 строк fallback-кода

**Архитектура:**
```
MapObjectProvider (Facade)
├── Управление списками объектов
├── Фильтрация
├── Создание объектов (фабричные методы)
└── Делегирование →
    ├── CreatureProvider (существа)
    ├── P2PProvider (синхронизация)
    ├── ModerationProvider (модерация)
    ├── NotificationProvider (уведомления)
    ├── ContactProvider (контакты)
    ├── InterestProvider (интересы)
    ├── ReminderProvider (напоминания)
    └── ForagingProvider (места сбора)
```

**Выгоды:**
- ✅ Каждый провайдер отвечает за одну область (SRP)
- ✅ Легче тестировать изолированно
- ✅ Меньше кода для понимания в каждом файле
- ✅ Нет дублирования логики
- ✅ Обратная совместимость API сохранена

### Коммиты рефакторинга
1. `e20090c` - Fix creature synchronization bugs
2. `c9a3ce6` - Fix distance calculation bugs
3. `cae9db7` - Fix analyzer warnings and async context issues
4. `b0f9648` - Replace deprecated withOpacity with withValues
5. `25b9cea` - Replace print with debugPrint in services
6. `6744634` - Fix style issues and remove unused imports
7. `4c5bbf0` - Fix more analyzer issues
8. `57e48df` - Split MapObjectProvider into specialized providers
9. `212855d` - MapObjectProvider as facade with delegation
10. `ea81e46` - Fix InterestProvider import and CatchResult.points
11. `8151874` - Remove fallback implementations (668 lines final)
