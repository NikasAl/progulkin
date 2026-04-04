/// Рефакторинг MapObjectProvider - версия с разделением ответственности
library;

/// 
/// Этот файл содержит реорганизованную версию MapObjectProvider,
/// которая делегирует функции специализированным провайдерам.
/// 
/// Новые провайдеры:
/// - CreatureProvider - управление существами
/// - P2PProvider - P2P синхронизация
/// - ModerationProvider - модерация объектов
/// - NotificationProvider - уведомления
/// - ContactProvider - профили контактов
/// - InterestProvider - интересы к заметкам
/// - ReminderProvider - напоминания
/// - ForagingProvider - места сбора
/// 
/// Использование:
/// 1. Создать экземпляры специализированных провайдеров
/// 2. Создать MapObjectProvider с ними
/// 3. Инициализировать через init()
/// 
/// Пример:
/// ```dart
/// final storage = MapObjectStorage();
/// 
/// final creatureProvider = CreatureProvider(storage: storage);
/// final p2pProvider = P2PProvider();
/// final moderationProvider = ModerationProvider(storage: storage);
/// final notificationProvider = NotificationProvider();
/// final contactProvider = ContactProvider(storage: storage);
/// final interestProvider = InterestProvider(storage: storage);
/// final reminderProvider = ReminderProvider(storage: storage);
/// final foragingProvider = ForagingProvider(storage: storage);
/// 
/// final mapObjectProvider = MapObjectProvider(
///   creatureProvider: creatureProvider,
///   p2pProvider: p2pProvider,
///   moderationProvider: moderationProvider,
///   notificationProvider: notificationProvider,
///   contactProvider: contactProvider,
///   interestProvider: interestProvider,
///   reminderProvider: reminderProvider,
///   foragingProvider: foragingProvider,
/// );
/// 
/// await mapObjectProvider.init();
/// ```

// Экспортируем все новые провайдеры
export 'creature_provider.dart';
export 'p2p_provider.dart';
export 'moderation_provider.dart';
export 'notification_provider.dart';
export 'contact_provider.dart';
export 'interest_provider.dart';
export 'reminder_provider.dart';
export 'foraging_provider.dart';
