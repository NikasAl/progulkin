#!/bin/bash
# f - Короткая команда для Flutter с автообновлением версии
#
# Использование:
#   ./f run                    # flutter run (обновит версию)
#   ./f run -d chrome          # flutter run -d chrome
#   ./f build apk              # flutter build apk
#   ./f build apk --release    # релизная сборка
#   ./f test                   # flutter test
#
# Добавьте алиас в ~/.bashrc:
#   alias f='/path/to/progulkin/f'
# Или создайте симлинк:
#   sudo ln -s /path/to/progulkin/f /usr/local/bin/f

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Обновление версии
update_version() {
    local COMMIT=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local VERSION=$(grep "^version:" "$SCRIPT_DIR/pubspec.yaml" | sed 's/version: \([0-9.]*\)+.*/\1/')
    local BUILD=$(grep "^version:" "$SCRIPT_DIR/pubspec.yaml" | sed 's/.*+\([0-9]*\)/\1/')
    
    cat > "$SCRIPT_DIR/lib/config/version.dart" << EOF
/// Информация о версии приложения
class AppVersion {
  AppVersion._();
  static const String version = '$VERSION';
  static const int buildNumber = $BUILD;
  static const String commitHash = '$COMMIT';
  static String get fullVersion => 'v\$version (\$commitHash)';
  static String get versionInfo => 'Версия \$version\nСборка \$buildNumber • \$commitHash';
}
EOF
    echo "✓ Version: $VERSION • Commit: $COMMIT"
}

# Проверяем команду
case "$1" in
    run|build)
        update_version
        ;;
esac

# Запускаем flutter
cd "$SCRIPT_DIR"
flutter "$@"
