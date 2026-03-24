# Анализ архитектуры Прогулкин

**Дата:** 2024
**Версия проекта:** 1.0.0
**Общий объём кода:** ~9,700 строк Dart

---

## 1. Текущая структура проекта

### 1.1. Распределение кода по слоям

| Слой | Файлов | Строк | % |
|------|--------|-------|---|
| **Screens** | 7 | ~4,800 | 49% |
| **Services** | 7 | ~2,100 | 22% |
| **Providers** | 3 | ~1,100 | 11% |
| **Models** | 8 | ~1,000 | 10% |
| **Widgets** | 4 | ~700 | 7% |

### 1.2. Самые большие файлы

| Файл | Строк | Проблема |
|------|-------|----------|
| `home_screen.dart` | 1,484 | 🔴 Критично |
| `settings_screen.dart` | 731 | 🟡 Внимание |
| `route_planning_screen.dart` | 657 | 🟡 Внимание |
| `walk_detail_screen.dart` | 544 | 🟢 Приемлемо |
| `map_objects_layer.dart` | 496 | 🟢 Приемлемо |

---

## 2. Проблемные места

### 2.1. HomeScreen - Бог-класс (1,484 строки)

**Проблема:** `HomeScreen` выполняет слишком много обязанностей:

```
HomeScreen (1,484 строки)
├── UI карты и слои
├── UI статистики прогулки
├── UI шагомера
├── UI нижних контролов
├── Логика прогулок (start/stop/pause)
├── Логика объектов карты
│   ├── Показ деталей
│   ├── Действия (уборка, чтение секрета)
│   ├── Опции объекта
│   └── Добавление объекта
├── Инициализация провайдеров
├── Таймеры обновления
└── _ObjectDetailsContent (внутренний класс, ~350 строк)
```

**Нарушения принципов:**
- ❌ Single Responsibility Principle (SRP)
- ❌ Высокая связанность (coupling)
- ❌ Сложность тестирования
- ❌ Сложность навигации по коду

### 2.2. Дублирование UI кода

**Проблема:** Методы `_buildInfoSection`, `_buildInfoRow`, `_getTitle` дублируют логику из `MapObjectInfoWidget` в `map_objects_layer.dart`.

```dart
// В home_screen.dart
Widget _buildInfoSection(BuildContext context) { ... }  // ~150 строк
Widget _buildInfoRow(...) { ... }

// В map_objects_layer.dart  
class MapObjectInfoWidget { 
  Widget _buildInfoGrid(...) { ... }  // Похожая логика
  Widget _buildInfoItem(...) { ... }
}
```

### 2.3. Смешивание UI и бизнес-логики

**Проблема:** Логика действий объектов (`_getObjectActionInfo`) находится в UI-слое:

```dart
// home_screen.dart - НЕПРАВИЛЬНО
Map<String, dynamic> _getObjectActionInfo(MapObject object, ...) {
  if (object.type == MapObjectType.trashMonster) {
    // Проверки, расчёты расстояния
    final distance = calculateDistance(...);
    if (distance > 100) {
      return {'action': null, 'hint': 'Подойдите ближе...'};
    }
    // ...
  }
}
```

### 2.4. Отсутствие абстракции для действий

**Проблема:** Каждое действие с объектом требует:
1. Проверку условий (прогулка, расстояние)
2. Вызов provider
3. Закрытие bottom sheet
4. Показ snackbar

Это дублируется для каждого типа объекта.

---

## 3. Рекомендации по рефакторингу

### 3.1. Разделение HomeScreen

**Приоритет:** 🔴 Высокий

Разделить `HomeScreen` на отдельные виджеты:

```
lib/
├── screens/
│   └── home/
│       ├── home_screen.dart           # ~200 строк (оркестрация)
│       ├── map_widget.dart            # Карта с маркерами
│       ├── walk_stats_panel.dart      # Статистика прогулки
│       ├── steps_panel.dart           # Панель шагомера
│       ├── bottom_controls.dart       # Кнопки управления
│       └── object_action_handler.dart # Обработка действий
└── widgets/
    └── object_details_sheet.dart      # BottomSheet с деталями
```

**Ожидаемый результат:**
- `home_screen.dart` → ~200 строк
- Каждый виджет → 150-300 строк
- Тестируемость ↑
- Переиспользование ↑

### 3.2. Выделение сервисов для объектов

**Приоритет:** 🟡 Средний

Создать `ObjectActionService`:

```dart
/// Сервис для действий с объектами
class ObjectActionService {
  final MapObjectProvider _objectProvider;
  final LocationService _locationService;
  
  /// Проверить возможность действия
  ActionResult canPerformAction(
    MapObject object, {
    required bool isWalking,
    required LatLng userLocation,
  });
  
  /// Выполнить действие
  Future<ActionResult> performAction(
    MapObject object,
    String userId, {
    required bool isWalking,
    required LatLng userLocation,
  });
}

/// Результат действия
class ActionResult {
  final bool success;
  final String? message;
  final int? points;
  final String? error;
}
```

### 3.3. Унификация деталей объекта

**Приоритет:** 🟢 Низкий

Объединить `_ObjectDetailsContent` и `MapObjectInfoWidget`:

```dart
/// Единый виджет для отображения деталей объекта
class ObjectDetailsSheet extends StatelessWidget {
  final MapObject object;
  final ObjectActionHandler? actionHandler;
  
  const ObjectDetailsSheet({
    super.key,
    required this.object,
    this.actionHandler,
  });
  
  @override
  Widget build(BuildContext context) { ... }
}
```

### 3.4. Модель для UI-состояния объекта

**Приоритет:** 🟢 Низкий

```dart
/// Состояние объекта для UI
class ObjectUIState {
  final MapObject object;
  final double? distanceToUser;
  final bool canInteract;
  final String? interactionHint;
  final bool isWalking;
  
  factory ObjectUIState.fromContext(
    MapObject object,
    BuildContext context,
  ) { ... }
}
```

---

## 4. План рефакторинга

### Этап 1: Выделение ObjectDetailsSheet (1-2 часа)
1. Перенести `_ObjectDetailsContent` в отдельный файл
2. Добавить необходимые параметры
3. Обновить использование в HomeScreen
4. Удалить дублирующий `MapObjectInfoWidget`

### Этап 2: Выделение ObjectActionService (2-3 часа)
1. Создать сервис с методами `canPerformAction`, `performAction`
2. Перенести логику из `_getObjectActionInfo`
3. Добавить юнит-тесты
4. Обновить HomeScreen

### Этап 3: Разделение HomeScreen (3-4 часа)
1. Создать папку `screens/home/`
2. Выделить `MapWidget`, `WalkStatsPanel`, `StepsPanel`, `BottomControls`
3. Создать `HomeScreen` как оркестратор
4. Обновить навигацию

---

## 5. Метрики качества кода

### До рефакторинга

| Метрика | Значение | Оценка |
|---------|----------|--------|
| Макс. размер файла | 1,484 | 🔴 Плохо |
| Средний размер файла | 140 | 🟢 Хорошо |
| Цикломатическая сложность | Высокая | 🟡 Средне |
| Дублирование кода | ~15% | 🟡 Средне |
| Тестируемость | Низкая | 🔴 Плохо |

### После рефакторинга (ожидаемое)

| Метрика | Значение | Оценка |
|---------|----------|--------|
| Макс. размер файла | ~400 | 🟢 Хорошо |
| Средний размер файла | 120 | 🟢 Хорошо |
| Цикломатическая сложность | Низкая | 🟢 Хорошо |
| Дублирование кода | <5% | 🟢 Хорошо |
| Тестируемость | Высокая | 🟢 Хорошо |

---

## 6. Выводы

### Что хорошо ✅

1. **Чистые модели** - `TrashMonster`, `SecretMessage`, `Creature` хорошо спроектированы
2. **Разделение Provider/Service** - чёткое разделение ответственности
3. **P2P архитектура** - модульная, расширяемая
4. **Офлайн-кэш карт** - хорошо инкапсулирован в `TileCacheService`

### Что требует внимания ⚠️

1. **HomeScreen** - главный кандидат на рефакторинг
2. **Дублирование UI** - унифицировать виджеты деталей объектов
3. **Смешивание слоёв** - вынести бизнес-логику из UI

### Приоритет действий

1. 🔴 **Сейчас:** Выделить `ObjectDetailsSheet` (низкий риск, высокий эффект)
2. 🟡 **Скоро:** Разделить `HomeScreen` на компоненты
3. 🟢 **Потом:** Создать `ObjectActionService` при добавлении новых типов объектов

---

## 7. Рекомендации для новых фич

При добавлении новых типов объектов (например, Существа):

1. **Модель** - наследовать от `MapObject`, реализовать `toSyncJson`/`fromSyncJson`
2. **Provider** - добавить метод `spawnCreature` в `MapObjectProvider`
3. **UI создания** - создать отдельный экран или форму в `AddObjectScreen`
4. **Действия** - добавить в `ObjectActionService` (после рефакторинга)
5. **Детали** - добавить секцию в `ObjectDetailsSheet`

---

*Документ создан для оценки поддерживаемости проекта*
