# Прогулкин 🚶

Flutter приложение для трекинга прогулок с отображением маршрутов на Яндекс карте и подсчётом шагов.

## Возможности

- 📍 **Запись маршрута** - отслеживание GPS позиции во время прогулки
- 🗺️ **Яндекс карты** - отображение маршрута на карте в реальном времени
- 👟 **Подсчёт шагов** - использование нативного шагомера или акселерометра
- 📊 **Статистика** - расстояние, время, средняя скорость
- 💾 **История прогулок** - сохранение всех прогулок локально
- 🌙 **Тёмная тема** - автоматическое переключение темы

## Структура проекта

```
lib/
├── main.dart                 # Точка входа
├── models/
│   ├── walk.dart            # Модель прогулки
│   └── walk_point.dart      # Модель точки маршрута
├── services/
│   ├── location_service.dart    # Сервис геолокации
│   ├── pedometer_service.dart   # Сервис шагомера
│   └── storage_service.dart     # Сервис хранения данных
├── providers/
│   ├── walk_provider.dart       # Управление прогулками
│   └── pedometer_provider.dart  # Управление шагомером
├── screens/
│   ├── home_screen.dart         # Главный экран с картой
│   ├── history_screen.dart      # История прогулок
│   └── walk_detail_screen.dart  # Детали прогулки
└── widgets/
    └── stats_widget.dart        # Виджеты статистики
```

## Установка

### Требования

- Flutter SDK 3.0+
- Android SDK 21+ / iOS 12+

### Настройка API ключей

1. Получите API ключ для Яндекс карт: https://developer.tech.yandex.ru/

2. Добавьте ключ в:
   - `android/app/src/main/AndroidManifest.xml` (тег `com.yandex.mapkit.apikey`)
   - `ios/Runner/Info.plist` (ключ `YandexMapKitApiKey`)
   - `lib/screens/home_screen.dart` (константа `_yandexApiKey`)

### Сборка

```bash
# Установка зависимостей
flutter pub get

# Запуск на устройстве
flutter run

# Сборка APK
flutter build apk --release

# Сборка для iOS
flutter build ios --release
```

## Разрешения

### Android
- `ACCESS_FINE_LOCATION` - точная геолокация
- `ACCESS_COARSE_LOCATION` - примерная геолокация
- `ACCESS_BACKGROUND_LOCATION` - геолокация в фоне
- `ACTIVITY_RECOGNITION` - распознавание активности (шагомер)

### iOS
- `NSLocationWhenInUseUsageDescription` - геолокация при использовании
- `NSLocationAlwaysAndWhenInUseUsageDescription` - постоянная геолокация
- `NSMotionUsageDescription` - данные о движении

## Зависимости

- `yandex_mapkit` - Яндекс карты
- `geolocator` - геолокация
- `pedometer` - шагомер
- `sensors_plus` - датчики (акселерометр)
- `provider` - управление состоянием
- `shared_preferences` - локальное хранилище
- `intl` - форматирование дат
- `uuid` - генерация идентификаторов

## Лицензия

MIT License
