/// Константы приложения Прогулкин
///
/// Централизованное хранение всех констант для упрощения поддержки
class AppConstants {
  AppConstants._();

  // ===========================================================================
  // РАДИУСЫ И РАССТОЯНИЯ
  // ===========================================================================

  /// Радиус верификации фото (метры)
  /// Фото можно сделать только если пользователь находится в этом радиусе от объекта
  static const double photoVerificationRadius = 100.0;

  /// Радиус уборки мусорного монстра (метры)
  static const double cleaningRadius = 20.0;

  /// Радиус ловли существ (метры)
  /// Ограничен точностью GPS ~20-30м
  static const double catchingRadius = 20.0;

  /// Радиус уведомлений о близлежащих объектах (метры)
  static const double nearbyAlertRadius = 100.0;

  /// Радиус взаимодействия с объектами по умолчанию (метры)
  static const double defaultInteractionRadius = 100.0;

  /// Минимальное расстояние для фильтрации GPS (метры)
  static const double minGpsFilterDistance = 5.0;

  // ===========================================================================
  // ПАРАМЕТРЫ ФОТО
  // ===========================================================================

  /// Максимальная ширина фото для превью (пиксели)
  static const int maxPhotoWidth = 800;

  /// Максимальная высота фото для превью (пиксели)
  static const int maxPhotoHeight = 600;

  /// Качество WebP сжатия (0-100)
  static const int webpQuality = 80;

  /// Качество WebP для оригинала (0-100)
  static const int webpOriginalQuality = 85;

  /// Максимальный размер фото для превью (KB)
  static const int maxPhotoSizeKB = 100;

  /// Максимальный размер оригинала фото (KB)
  static const int maxOriginalSizeKB = 250;

  /// Размер миниатюры (пиксели)
  static const int thumbnailSize = 200;

  /// Качество миниатюры (0-100)
  static const int thumbnailQuality = 75;

  /// Максимальное количество фото на объект
  static const int maxPhotosPerObject = 5;

  /// Максимальная ширина при съёмке камерой
  static const int cameraMaxWidth = 1200;

  /// Максимальная высота при съёмке камерой
  static const int cameraMaxHeight = 900;

  /// Качество при съёмке камерой (до сжатия)
  static const int cameraQuality = 85;

  // ===========================================================================
  // ТАЙМАУТЫ
  // ===========================================================================

  /// Таймаут GPS позиционирования
  static const Duration gpsTimeout = Duration(seconds: 30);

  /// Таймаут P2P соединения
  static const Duration p2pConnectionTimeout = Duration(seconds: 60);

  /// Интервал обновления локации при прогулке
  static const Duration locationUpdateInterval = Duration(seconds: 1);

  /// Длительность анимации уведомления
  static const Duration notificationAnimationDuration = Duration(milliseconds: 300);

  /// Время показа уведомления о близлежащем объекте
  static const Duration nearbyAlertDuration = Duration(seconds: 5);

  /// Длительность пульсации для индикаторов
  static const Duration pulseAnimationDuration = Duration(milliseconds: 1500);

  // ===========================================================================
  // НАСТРОЙКИ ПО УМОЛЧАНИЮ
  // ===========================================================================

  /// Сглаживание маршрута по умолчанию
  static const bool defaultEnableSmoothing = false;

  /// Определение неподвижности по умолчанию
  static const bool defaultEnableStationaryDetection = true;

  /// Шагомер по умолчанию
  static const bool defaultEnablePedometer = true;

  /// Источник расстояния по умолчанию ('gps' или 'pedometer')
  static const String defaultDistanceSource = 'gps';

  // ===========================================================================
  // P2P СИНХРОНИЗАЦИЯ
  // ===========================================================================

  /// Максимальный размер сообщения для P2P (байты)
  static const int maxP2PMessageSize = 1024 * 1024; // 1 MB

  /// Интервал синхронизации объектов
  static const Duration syncInterval = Duration(seconds: 30);

  /// Максимальное количество объектов в одном синхрон-пакете
  static const int maxObjectsPerSync = 100;

  // ===========================================================================
  // БАЗЫ ДАННЫХ
  // ===========================================================================

  /// Версия базы данных
  static const int databaseVersion = 5;

  /// Имя файла базы данных
  static const String databaseName = 'progulkin.db';

  // ===========================================================================
  // КАРТЫ
  // ===========================================================================

  /// URL тайлов OpenStreetMap
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Минимальный зум карты
  static const double minMapZoom = 10.0;

  /// Максимальный зум карты
  static const double maxMapZoom = 19.0;

  /// Зум карты по умолчанию
  static const double defaultMapZoom = 16.0;

  /// Максимальное количество закэшированных тайлов
  static const int maxCachedTiles = 10000;
}

/// Константы для UI
class UIConstants {
  UIConstants._();

  /// Размер иконки в списке
  static const double listIconSize = 24.0;

  /// Размер эмодзи в маркере карты
  static const double mapEmojiSize = 28.0;

  /// Размер фото в списке
  static const double photoListSize = 100.0;

  /// Размер фото в галерее
  static const double photoGallerySize = 120.0;

  /// Скругление углов карточек
  static const double cardBorderRadius = 12.0;

  /// Скругление углов фото
  static const double photoBorderRadius = 8.0;

  /// Отступ между элементами
  static const double itemSpacing = 8.0;

  /// Отступ между секциями
  static const double sectionSpacing = 16.0;

  /// Отступ от края экрана
  static const double screenPadding = 16.0;
}

/// Константы для расчёта очков
class PointsConstants {
  PointsConstants._();

  /// Базовые очки за уборку монстра (умножается на уровень и количество)
  static const int baseCleaningPoints = 10;

  /// Очки за создание объекта
  static const int objectCreationPoints = 10;

  /// Очки за подтверждение объекта
  static const int confirmPoints = 5;

  /// Очки за поимку существа
  static const int creatureCatchPoints = 15;

  /// Бонус за редкость существа
  static const Map<String, int> rarityBonus = {
    'common': 0,
    'uncommon': 5,
    'rare': 15,
    'epic': 30,
    'legendary': 50,
    'mythical': 100,
  };
}
