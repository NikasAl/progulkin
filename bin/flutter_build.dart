#!/usr/bin/env dart
/// Точка входа для Flutter команд с автоматическим обновлением версии
///
/// Использование:
///   dart run bin/flutter_build.dart run -d <device>
///   dart run bin/flutter_build.dart build apk
///
/// Или добавьте в pubspec.yaml:
///   executables:
///     progulkin-build: flutter_build
///
/// Тогда можно будет запускать:
///   dart pub global run progulkin_build run
///   dart pub global run progulkin_build build apk

import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    printUsage();
    exit(1);
  }

  final command = args[0];
  final projectDir = Directory.current.path;

  // Обновляем версию перед build или run
  if (['run', 'build'].contains(command)) {
    await updateVersion(projectDir);
  }

  // Выполняем flutter команду
  await runFlutter(args);
}

void printUsage() {
  print('''
Flutter build wrapper with automatic version update

Usage:
  dart run bin/flutter_build.dart <command> [arguments]

Commands:
  run       Run app (flutter run) - updates version first
  build     Build app (flutter build) - updates version first
  test      Run tests (flutter test)
  *         Any other flutter command (passed through)

Examples:
  dart run bin/flutter_build.dart run -d chrome
  dart run bin/flutter_build.dart build apk --release
  dart run bin/flutter_build.dart build ios
''');
}

Future<void> updateVersion(String projectDir) async {
  print('📝 Updating version info...');

  // Получаем версию из pubspec.yaml
  final pubspecFile = File('$projectDir/pubspec.yaml');
  String version = '1.0.0';
  int buildNumber = 1;

  if (await pubspecFile.exists()) {
    final content = await pubspecFile.readAsString();
    final versionMatch = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)',
      multiLine: true,
    ).firstMatch(content);
    if (versionMatch != null) {
      version = versionMatch.group(1)!;
      buildNumber = int.parse(versionMatch.group(2)!);
    }
  }

  // Получаем хэш коммита
  String commitHash = 'unknown';
  try {
    final result = await Process.run(
      'git',
      ['rev-parse', '--short', 'HEAD'],
      workingDirectory: projectDir,
    );
    if (result.exitCode == 0) {
      commitHash = (result.stdout as String).trim();
    }
  } catch (e) {
    print('   Warning: Could not get git commit hash');
  }

  // Генерируем файл версии
  final versionFileContent = '''/// Информация о версии приложения
///
/// Этот файл генерируется автоматически перед сборкой
/// Не редактируйте вручную - изменения будут перезаписаны
class AppVersion {
  AppVersion._();

  /// Версия приложения (из pubspec.yaml)
  static const String version = '$version';

  /// Номер сборки
  static const int buildNumber = $buildNumber;

  /// Хэш коммита Git (короткий)
  /// Обновляется автоматически при каждой сборке
  static const String commitHash = '$commitHash';

  /// Полная строка версии для отображения
  static String get fullVersion => 'v\$version (\$commitHash)';

  /// Полная информация о версии
  static String get versionInfo => 'Версия \$version\\nСборка \$buildNumber • \$commitHash';
}
''';

  final versionFile = File('$projectDir/lib/config/version.dart');
  await versionFile.writeAsString(versionFileContent);

  print('   Version: $version');
  print('   Build: $buildNumber');
  print('   Commit: $commitHash');
  print('');
}

Future<void> runFlutter(List<String> args) async {
  print('🚀 Running: flutter ${args.join(' ')}');
  print('');

  final process = await Process.start(
    'flutter',
    args,
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await process.exitCode;
  exit(exitCode);
}
