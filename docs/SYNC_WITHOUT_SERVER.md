# Синхронизация карты без сигнального сервера

## Обзор

Система синхронизации позволяет обмениваться объектами карты между устройствами без необходимости разворачивать отдельный сигнальный сервер.

## Методы синхронизации

### 1. Файловый обмен (рекомендуется)

Экспорт данных в ZIP-архив с возможностью передачи через любой канал:
- Мессенджеры (Telegram, WhatsApp)
- Email
- USB-накопитель
- Облачные хранилища

### 2. Будущие методы (планируются)

- **WiFi LAN** — автоматическое обнаружение устройств в локальной сети
- **QR-код** — быстрый обмен отдельными объектами
- **Bluetooth** — прямой обмен между устройствами

## Формат файла экспорта

Файл экспорта имеет расширение `.progulkin` и представляет собой ZIP-архив:

```
Прогулкин_экспорт.progulkin
├── manifest.json        # Метаданные экспорта
├── objects.json         # Все объекты карты
├── preview.json         # Превью для быстрого просмотра
└── photos/              # Папка с фотографиями
    ├── uuid1.webp
    ├── uuid2.webp
    └── ...
```

### manifest.json
```json
{
  "formatVersion": 2,
  "appName": "Progulkin",
  "exportDate": "2024-03-30T12:00:00Z",
  "deviceId": "device_123",
  "totalObjects": 42,
  "totalPhotos": 15,
  "description": "Экспорт карты Прогулкин"
}
```

### objects.json
Массив объектов в формате JSON, каждый объект содержит:
- Базовые поля: `id`, `type`, `latitude`, `longitude`, `ownerId`
- Временные метки: `createdAt`, `updatedAt`, `deletedAt`
- Статус: `status`, `confirms`, `denies`, `views`, `version`
- Специфичные поля типа объекта

## Merge Engine

### Алгоритм слияния

При импорте выполняется интеллектуальное слияние данных:

1. **Новые объекты** — добавляются автоматически
2. **Идентичные объекты** — пропускаются
3. **Изменённые объекты** — разрешаются по стратегии

### Стратегии разрешения конфликтов

| Стратегия | Описание |
|-----------|----------|
| `localWins` | Локальная версия приоритетнее |
| `remoteWins` | Входящая версия приоритетнее |
| `newerWins` | Побеждает версия с более поздним `updatedAt` |
| `mergeBoth` | Попытка объединить (для счётчиков) |
| `askUser` | Требуется решение пользователя |

### Типы конфликтов

| Тип | Описание |
|-----|----------|
| `bothModified` | Обе стороны изменили объект |
| `localDeletedRemoteModified` | Удалён локально, изменён удалённо |
| `localModifiedRemoteDeleted` | Изменён локально, удалён удалённо |
| `bothDeleted` | Удалён в обоих местах |
| `versionMismatch` | Несовпадение версий |

### Умный мерж для TrashMonster

Для мусорных монстров применяется специальная логика:
- Счётчики (`confirms`, `denies`, `views`) — берётся максимум
- Фото — объединяются списки
- Статус уборки — если убран где-то, считается убранным

## Soft Delete

Объекты не удаляются физически, а помечаются как удалённые:
- Поле `deletedAt` устанавливается в время удаления
- `status` меняется на `hidden`
- Удалённые объекты участвуют в мерже

Это позволяет корректно синхронизировать удаления между устройствами.

## Использование

### Экспорт

```dart
final syncService = SyncService();
final result = await syncService.exportAndShare();

if (result.success) {
  print('Экспортировано: ${result.objectsCount} объектов');
}
```

### Импорт

```dart
final syncService = SyncService();
final result = await syncService.importFromZip(
  strategy: MergeStrategy.newerWins,
);

if (result.success) {
  print('Импорт завершён: ${result.summary}');
  
  if (result.hasConflicts) {
    // Показать диалог разрешения конфликтов
    for (final conflict in result.conflicts!) {
      // Разрешить конфликт
      await syncService.resolveConflict(
        conflict,
        MergeStrategy.newerWins,
      );
    }
  }
}
```

## Структура данных

### MapObject (базовый класс)

```dart
class MapObject {
  final String id;
  final MapObjectType type;
  final double latitude;
  final double longitude;
  final String ownerId;
  final String ownerName;
  final int ownerReputation;
  final DateTime createdAt;
  final DateTime updatedAt;    // Для мержа
  final DateTime? expiresAt;
  final DateTime? deletedAt;   // Soft delete
  MapObjectStatus status;
  int confirms;
  int denies;
  int views;
  int version;
}
```

### MapObjectStorage

Хранилище SQLite с поддержкой:
- CRUD операций
- Soft delete
- Хранения фото (WebP)
- Индексации по geohash

## Рекомендации по использованию

### Для групповой работы

1. **Регулярный экспорт** — после значительных изменений
2. **Импорт с проверкой** — всегда просматривать превью
3. **Разрешение конфликтов** — использовать `newerWins` по умолчанию

### Для больших объёмов

- Файл экспорта может достигать нескольких МБ при большом количестве фото
- Рекомендуется периодическая очистка удалённых объектов
- Фото сжимаются до WebP формата для экономии места

## Безопасность

- Файлы экспорта не шифруются
- Не рекомендуется передавать файлы через незащищённые каналы
- Секретные сообщения передаются в зашифрованном виде

## Будущие улучшения

1. **Инкрементальная синхронизация** — передача только изменений
2. **Сжатие архива** — дополнительное сжатие для экономии места
3. **Шифрование** — защита данных при передаче
4. **WiFi Direct** — прямая синхронизация между устройствами
