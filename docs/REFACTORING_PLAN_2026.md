# План рефакторинга Прогулкин - 2026

**Дата создания:** 2026-04-15
**Последнее обновление:** 2026-04-15
**Статус:** В процессе выполнения

---

## 1. Текущее состояние архитектуры

### 1.1. Размеры основных файлов (актуально на 2026-04-15)

| Файл | Строк | Статус | Изменение |
|------|-------|--------|-----------|
| `object_details_sheet.dart` | 1120 | ⏳ Частично разделён | Был 1138 |
| `add_object_screen.dart` | 372 | ✅ **Разделён** | ~~1021~~ → 372 (-64%) |
| `home_screen.dart` | 846 | ✅ **Разделён** | ~~1415~~ → 846 (-40%) |
| `settings_screen.dart` | 461 | ✅ **Разделён** | ~~1217~~ → 461 (-62%) |
| `map_object_storage.dart` | 783 | ⏳ Не разделён | God Service |
| `map_objects_layer.dart` | 777 | ✅ Исправлено | Баг с артефактами |
| `history_screen.dart` | 776 | ✅ Оптимизирован | Убрано дублирование |
| `storage_screen.dart` | 733 | ✅ Оптимизирован | Убрано дублирование |
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

#### ✅ **Фаза 2.3: AddObjectScreen (завершён)**
- 1021 → 372 строк (64% сокращение)
- Создана папка `lib/screens/add_object/`
- Вынесены формы:
  - `trash_monster_form.dart` (190 строк)
  - `secret_message_form.dart` (156 строк)
  - `interest_note_form.dart` (206 строк)
  - `reminder_form.dart` (119 строк)
  - `foraging_spot_form.dart` (281 строк)

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

#### ObjectDetailsSheet (1120 строк)
**Текущий статус:** Частично разделён, есть папка `object_details/`

**План:**
```
lib/widgets/object_details/
├── object_details_sheet.dart  (~200 строк - структура)
├── details/
│   ├── trash_monster_details.dart
│   ├── creature_details.dart
│   ├── secret_message_details.dart
│   ├── interest_note_details.dart
│   └── reminder_details.dart
└── photo_gallery_widget.dart (уже существует)
```

#### MapObjectStorage (783 строки) - God Service
**План:** Разделить на репозитории
```
lib/repositories/
├── map_object_repository.dart
├── photo_repository.dart
├── message_repository.dart
└── contact_repository.dart
```

### 2.2. Приоритет P2

- [ ] Внедрение GetIt для DI
- [ ] Абстракции сервисов для тестирования
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
│   └── settings/
│       └── settings_screen.dart (461 строк)
├── widgets/
│   ├── object_details/
│   │   ├── object_details_sheet.dart (1120 строк)
│   │   └── photo_gallery.dart
│   └── stats_widget.dart
├── services/
│   └── p2p/map_object_storage.dart (783 строк)
└── utils/
    ├── snackbar_helper.dart
    └── panel_decorations.dart
```

---

## 5. Метрики успеха

| Метрика | До | Сейчас | Цель |
|---------|-----|--------|------|
| Файлов > 1000 строк | 4 | **0** | 0 ✅ |
| Файлов > 500 строк | 8 | **5** | 2-3 |
| Средний размер экрана | 800 | **~400** | 250 |
| Дублирование кода | Высокое | **Низкое** | Минимальное |

---

## 6. Коммиты рефакторинга

| Дата | Коммит | Описание |
|------|--------|----------|
| 2026-04-15 | `600b16e` | Разделение HomeScreen |
| 2026-04-15 | `b91373f` | Устранение дублирования кода |
| 2026-04-15 | `0788cb4` | Разделение AddObjectScreen |

---

*Документ обновлён: 2026-04-15*
