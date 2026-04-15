#!/usr/bin/env dart
/// Скрипт для обновления информации о версии в lib/config/version.dart
///
/// Запуск: dart run scripts/update_version.dart
///
/// Можно добавить в pre-build hook или запускать перед сборкой:
/// flutter pub run scripts/update_version.dart && flutter build apk

import 'dart:io';

void main() async {
  final projectDir = Platform.environment['PROJECT_DIR'] ?? 
      Directory.current.path;
  
  // Получаем версию из pubspec.yaml
  final pubspecFile = File('$projectDir/pubspec.yaml');
  String version = '1.0.0';
  int buildNumber = 1;
  
  if (await pubspecFile.exists()) {
    final content = await pubspecFile.readAsString();
    final versionMatch = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', 
        multiLine: true).firstMatch(content);
    if (versionMatch != null) {
      version = versionMatch.group(1)!;
      buildNumber = int.parse(versionMatch.group(2)!);
    }
  }
  
  // Получаем хэш коммита
  String commitHash = 'unknown';
  try {
    final result = await Process.run(
      'git', ['rev-parse', '--short', 'HEAD'],
      workingDirectory: projectDir,
    );
    if (result.exitCode == 0) {
      commitHash = (result.stdout as String).trim();
    }
  } catch (e) {
    print('Warning: Could not get git commit hash: $e');
  }
  
  // Генерируем содержимое файла
  final versionFileContent = '''/// Информация о версии приложения
///
/// Этот файл генерируется скриптом scripts/update_version.dart
/// Не редактируйте вручную - изменения будут перезаписаны
class AppVersion {
  AppVersion._();

  /// Версия приложения (из pubspec.yaml)
  static const String version = '$version';

  /// Номер сборки
  static const int buildNumber = $buildNumber;

  /// Хэш коммита Git (короткий)
  /// Обновляется автоматически при сборке
  static const String commitHash = '$commitHash';

  /// Полная строка версии для отображения
  static String get fullVersion => 'v\$version (\$commitHash)';

  /// Полная информация о версии
  static String get versionInfo => 'Версия \$version\\nСборка \$buildNumber • \$commitHash';
}
''';
  
  // Записываем файл
  final versionFile = File('$projectDir/lib/config/version.dart');
  await versionFile.writeAsString(versionFileContent);
  
  print('✅ Version file updated:');
  print('   Version: $version');
  print('   Build: $buildNumber');
  print('   Commit: $commitHash');
}
