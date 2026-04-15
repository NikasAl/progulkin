# План рефакторинга Прогулкин - 2026

**Дата создания:** 2026-04-15
**Последнее обновление:** 2026-04-16
**Статус:** В процессе выполнения

---

## 1. Текущее состояние архитектуры

### 1.1. Размеры основных файлов (актуально на 2026-04-16)

| Файл | Строк | Статус | Изменение |
|------|-------|--------|-----------|
| `home_screen.dart` | 846 | ✅ **Разделён** | ~~1415~~ → 846 (-40%) |
| `map_object_storage.dart` | 783 | ⏳ Не разделён | God Service |
| `map_objects_layer.dart` | 777 | ✅ Исправлено | Баг с артефактами |
| `history_screen.dart` | 776 | ✅ Оптимизирован | Убрано дублирование |
| `storage_screen.dart` | 733 | ✅ Оптимизирован | Убрано дублирование |
| `add_object_screen.dart` | 372 | ✅ **Разделён** | ~~1021~~ → 372 (-64%) |
| `object_details_sheet.dart` | 370 | ✅ **Разделён** | ~~1120~~ → 370 (-67%) |
| `settings_screen.dart` | 461 | ✅ **Разделён** | ~~1217~~ → 461 (-62%) |
| `map_object_provider.dart` | 668 | ✅ Рефакторинг завершён | Facade pattern |

### 1.2. Выполненные улучшения

#### ✅ **Фаза 2.1: HomeScreen (завершён)**
- 1415 → 846 строк (40% сокращение)
- Создана папка `lib/screens/home/`
- Вынесены компоненты:
  - `walk_stats_panel.dart` (121 строк)
  - `walk_control_panel.dart` (238 строк)
  - `contact_author_sheet.dart` (170 строк)
  - `object_options_sheet.dart` (115 строк)

#### ✅ **Фаза 2.2: AddObjectScreen (завершён)**
- 1021 → 372 строк (64% сокращение)
- Создана папка `lib/screens/add_object/`
- Вынесены формы:
  - `trash_monster_form.dart` (190 строк)
  - `secret_message_form.dart` (156 строк)
  - `interest_note_form.dart` (206 строк)
  - `reminder_form.dart` (119 строк)
  - `foraging_spot_form.dart` (281 строк)

#### ✅ **Фаза 2.3: ObjectDetailsSheet (завершён)**
- 1120 → 370 строк (67% сокращение)
- Создана папка `lib/widgets/object_details/details/`
- Вынесены компоненты:
  - `trash_monster_details.dart` (70 строк)
  - `secret_message_details.dart` (43 строки)
  - `creature_details.dart` (53 строки)
  - `interest_note_details.dart` (35 строк)
  - `reminder_details.dart` (197 строк)
  - `info_row.dart` (42 строки)

#### ✅ **MapObjectProvider → Facade + 8 провайдеров**
- CreatureProvider (267 строк) - спавн/поимка существ
- P2PProvider (119 строк) - синхронизация
- ModerationProvider (103 строки) - модерация
- NotificationProvider (60 строк) - уведомления
- ContactProvider (99 строк) - контакты
- InterestProvider (109 строк) - интересы
- ReminderProvider (80 строк) - напоминания
- ForagingProvider (81 строка) - места сбора

#### ✅ **Устранение дублирования кода**
- Создан `lib/utils/snackbar_helper.dart` - helper-функции для SnackBar
- Создан `lib/utils/panel_decorations.dart` - общие декорации
- Расширен `StatsWidget` - 4 стиля: standard, compact, card, inline
- Заменены локальные `_buildStatItem` на унифицированный `StatsWidget`

#### ✅ **Исправлены warnings и deprecated API**
- withOpacity → withValues (94 замены)
- print → debugPrint (41 замена)
- Добавлены проверки mounted

#### ✅ **Исправлен баг с артефактами маркеров**
- Добавлены ValueKey для Marker и _MarkerWidget

---

## 2. Оставшиеся задачи

### 2.1. Приоритет P1

#### MapObjectStorage (783 строки) - God Service
**План:** Разделить на репозитории
```
lib/repositories/
├── map_object_repository.dart
├── photo_repository.dart
├── message_repository.dart
└── contact_repository.dart
```

**Примечание:** Требует существенных изменений архитектуры и может быть отложен.

### 2.2. Приоритет P2

#### ✅ DI Migration: GetIt внедрён (завершён)
**Статус:** Завершён

**Выполнено:**
- ✅ `lib/di/service_locator.dart` создан (92 строки, 17 сервисов)
- ✅ GetIt инициализируется в `main.dart` через `setupDependencies()`
- ✅ **19 использований `getIt<>`** (было 8)
- ✅ **Singleton factory pattern удалён** из всех сервисов

**Мигрированные файлы:**

| Категория | Файлы | Статус |
|-----------|-------|--------|
| **Сервисы** | `interest_notification_service.dart`, `sync_service.dart`, `map_object_export_service.dart`, `p2p_service.dart`, `incoming_file_service.dart` | ✅ Завершено |
| **Провайдеры** | `creature_provider.dart`, `p2p_provider.dart`, `chat_provider.dart`, `map_object_provider.dart`, `notification_provider.dart`, `walk_provider.dart`, `pedometer_provider.dart` | ✅ Завершено |
| **main.dart** | Инициализация DI, инъекция в провайдеры | ✅ Завершено |

**Оставшиеся файлы (низкий приоритет):**
- Экраны: `home_screen.dart`, `settings_screen.dart`, `habitat_debug_screen.dart`, `route_planning_screen.dart`, `walk_detail_screen.dart`, `storage_screen.dart`, `profile_screen.dart`
- Виджеты: `photo_capture_widget.dart`, `sync_dialog.dart`, `object_details_sheet.dart`
- Сервисы: `creature_service.dart`, `tile_cache_service.dart`, `tile_color_habitat_service.dart`

---

#### Другие задачи P2
- [ ] Абстракции сервисов для тестирования (интерфейсы)
- [ ] Вынести гео-утилиты в `lib/utils/geo_utils.dart`

---

## 3. Созданные утилиты

### lib/utils/snackbar_helper.dart
```dart
// Helper-функции
showInfoSnackBar(context, message)
showSuccessSnackBar(context, message)
showErrorSnackBar(context, message)
showWarningSnackBar(context, message)

// Extension методы
context.showInfo(message)
context.showSuccess(message)
context.showError(message)
context.showWarning(message)
```

### lib/utils/panel_decorations.dart
```dart
// Декорации
topPanelDecoration(context)
bottomPanelDecoration(context)
bottomSheetDecoration(context)
cardDecoration(context)

// Разделители
verticalDivider(height)
horizontalDivider(width)
```

### lib/widgets/stats_widget.dart
```dart
// Стили
StatsWidget(style: StatsWidgetStyle.standard)
StatsWidget.card(...)
StatsWidget.compact(...)
StatsWidget.inline(...)
```

---

## 4. Структура проекта (актуальная)

```
lib/
├── main.dart
├── di/
│   └── service_locator.dart (DI контейнер)
├── config/
│   ├── constants.dart
│   └── version.dart
├── models/
├── providers/
│   ├── map_object_provider.dart (Facade)
│   ├── creature_provider.dart
│   ├── p2p_provider.dart
│   └── ... (8 провайдеров)
├── screens/
│   ├── home/
│   │   ├── home_screen.dart (846 строк)
│   │   ├── walk_stats_panel.dart
│   │   ├── walk_control_panel.dart
│   │   └── ...
│   ├── add_object/
│   │   ├── add_object.dart (barrel)
│   │   ├── trash_monster_form.dart
│   │   ├── secret_message_form.dart
│   │   └── ... (5 форм)
│   └── settings_screen.dart (461 строк)
├── widgets/
│   ├── object_details/
│   │   ├── object_details_sheet.dart (370 строк)
│   │   ├── details/
│   │   │   ├── trash_monster_details.dart
│   │   │   ├── creature_details.dart
│   │   │   └── ... (6 файлов)
│   │   └── photo_gallery.dart
│   └── stats_widget.dart
├── services/
│   ├── p2p/map_object_storage.dart (783 строк)
│   └── ... (17 сервисов в DI)
└── utils/
    ├── snackbar_helper.dart
    └── panel_decorations.dart
```

---

## 5. Метрики успеха

| Метрика | До | Сейчас | Цель |
|---------|-----|--------|------|
| Файлов > 1000 строк | 4 | **0** ✅ | 0 ✅ |
| Файлов > 500 строк | 8 | **5** | 2-3 |
| Средний размер экрана | 800 | **~350** | 250 |
| Дублирование кода | Высокое | **Низкое** | Минимальное |
| Использований DI | 8 | **19+** | 30+ |

---

## 6. Коммиты рефакторинга

| Дата | Коммит | Описание |
|------|--------|----------|
| 2026-04-15 | `600b16e` | Разделение HomeScreen |
| 2026-04-15 | `b91373f` | Устранение дублирования кода |
| 2026-04-15 | `0788cb4` | Разделение AddObjectScreen |
| 2026-04-15 | `32d4026` | Обновление документации |
| 2026-04-15 | `f1edcdb` | Разделение ObjectDetailsSheet |
| 2026-04-15 | `b2fdee0` | Анализ DI и план миграции |
| 2026-04-16 | `b5e7a9f` | Миграция на DI через GetIt |
| 2026-04-16 | `babd0c9` | Продолжение миграции на DI |
| 2026-04-16 | `9d024e6` | Удаление singleton factory pattern |

---

## 7. Итоги

### ✅ Достигнуто:
- **4 God Widget** успешно разделены (HomeScreen, AddObjectScreen, ObjectDetailsSheet, SettingsScreen)
- **0 файлов** больше 1000 строк
- Устранено дублирование кода
- Созданы переиспользуемые утилиты
- **DI миграция** сервисов и провайдеров завершена (19+ использований getIt)
- **Singleton factory pattern** полностью удалён из сервисов

### ⏳ Отложено:
- MapObjectStorage (God Service) - требует изменения архитектуры БД
- DI миграция экранов и виджетов - низкий приоритет

---

*Документ обновлён: 2026-04-16*
