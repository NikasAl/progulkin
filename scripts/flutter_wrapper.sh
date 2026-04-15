#!/bin/bash
# flutter_wrapper.sh - Обёртка для Flutter команд с автоматическим обновлением версии
#
# Использование:
#   ./flutter_wrapper.sh run -d <device_id>
#   ./flutter_wrapper.sh build apk
#   ./flutter_wrapper.sh build ios
#
# Или создайте алиас:
#   alias flutter='./flutter_wrapper.sh'

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Обновляем версию перед любой командой build или run
update_version() {
    echo "📝 Updating version info..."
    cd "$PROJECT_DIR"
    dart run scripts/update_version.dart 2>/dev/null || {
        # Fallback если dart не доступен
        local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        local version=$(grep "^version:" pubspec.yaml | sed 's/version: \([0-9.]*\)+.*/\1/')
        local build=$(grep "^version:" pubspec.yaml | sed 's/.*+\([0-9]*\)/\1/')
        
        cat > lib/config/version.dart << EOF
/// Информация о версии приложения
class AppVersion {
  AppVersion._();

  static const String version = '$version';
  static const int buildNumber = $build;
  static const String commitHash = '$commit_hash';
  static String get fullVersion => 'v\$version (\$commitHash)';
  static String get versionInfo => 'Версия \$version\nСборка \$buildNumber • \$commitHash';
}
EOF
        echo "   Version: $version"
        echo "   Commit: $commit_hash"
    }
}

# Проверяем, нужна ли команда flutter
need_version_update() {
    case "$1" in
        run|build)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Главная логика
if need_version_update "$1"; then
    update_version
    echo ""
fi

# Выполняем flutter команду
echo "🚀 Running: flutter $@"
echo ""
cd "$PROJECT_DIR"
flutter "$@"
