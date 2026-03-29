#!/bin/bash
#
# Главный скрипт для подготовки к записи видеообзора
# Запускает зеркалирование телефона и готовит всё для записи
#
# Использование:
#   ./demo_setup.sh [режим]
#
# Режимы:
#   adb     - Использовать Python скрипт с adb (по умолчанию)
#   scrcpy  - Использовать scrcpy (нужна установка)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    ПРОГУЛКИН - Demo Setup                        ║"
echo "║                   Подготовка к видеообзору                       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

MODE="${1:-adb}"

# Проверяем подключение телефона
echo "📱 Проверка подключения телефона..."

if ! command -v adb &> /dev/null; then
    echo ""
    echo "❌ adb не установлен!"
    echo ""
    echo "Установка adb:"
    echo "  Ubuntu/Debian: sudo apt install android-tools-adb"
    echo "  Fedora:        sudo dnf install android-tools"
    echo "  Arch:          sudo pacman -S android-tools"
    echo ""
    exit 1
fi

DEVICE_COUNT=$(adb devices 2>/dev/null | grep -c "device$" || true)
if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo ""
    echo "❌ Телефон не подключен!"
    echo ""
    echo "1. Включите 'Отладка по USB' на телефоне:"
    echo "   Настройки → Для разработчиков → Отладка по USB"
    echo ""
    echo "2. Подключите телефон к компьютеру по USB"
    echo ""
    echo "3. Подтвердите отладку в диалоге на телефоне"
    echo ""
    exit 1
fi

DEVICE_INFO=$(adb devices | grep "device$" | head -1)
echo "✅ Подключено: $DEVICE_INFO"
echo ""

# Запускаем зеркалирование
case "$MODE" in
    adb)
        echo "🖥️  Запуск зеркалирования через adb + Python..."
        
        # Проверяем Python зависимости
        python3 -c "import tkinter; from PIL import Image, ImageTk" 2>/dev/null || {
            echo "❌ Не установлены Python зависимости!"
            echo ""
            echo "Установка:"
            echo "  sudo apt install python3-tk python3-pil python3-pil.imagetk"
            exit 1
        }
        
        # Запускаем зеркалирование
        echo "📺 Откроется окно с экраном телефона"
        echo "📹 Для записи используйте ./record_screen.sh в другом терминале"
        echo ""
        
        python3 "$SCRIPT_DIR/phone_mirror.py" --interval-ms 300 --scale 0.45 --title "📱 Прогулкин - Демо"
        ;;
        
    scrcpy)
        echo "🖥️  Запуск зеркалирования через scrcpy..."
        
        if ! command -v scrcpy &> /dev/null; then
            echo "❌ scrcpy не установлен!"
            echo ""
            echo "Установка:"
            echo "  Ubuntu/Debian: sudo apt install scrcpy"
            echo "  Fedora:        sudo dnf install scrcpy"
            echo "  Arch:          sudo pacman -S scrcpy"
            exit 1
        fi
        
        bash "$SCRIPT_DIR/phone_mirror_scrcpy.sh"
        ;;
        
    *)
        echo "❌ Неизвестный режим: $MODE"
        echo "   Используйте: adb или scrcpy"
        exit 1
        ;;
esac
