/// Информация о версии приложения
///
/// Этот файл генерируется скриптом scripts/update_version.dart
/// Не редактируйте вручную - изменения будут перезаписаны
class AppVersion {
  AppVersion._();

  /// Версия приложения (из pubspec.yaml)
  static const String version = '1.0.0';

  /// Номер сборки
  static const int buildNumber = 1;

  /// Хэш коммита Git (короткий)
  /// Обновляется автоматически при сборке
  static const String commitHash = '8699a26';

  /// Полная строка версии для отображения
  static String get fullVersion => 'v$version ($commitHash)';

  /// Полная информация о версии
  static String get versionInfo => 'Версия $version\nСборка $buildNumber • $commitHash';
}
