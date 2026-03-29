#!/bin/bash
#
# Скрипт для захвата экрана телефона через scrcpy (более плавное зеркалирование)
#
# Установка scrcpy:
#   Ubuntu/Debian: sudo apt install scrcpy
#   Fedora:        sudo dnf install scrcpy
#   Arch:          sudo pacman -S scrcpy
#   macOS:         brew install scrcpy
#
# Использование:
#   ./phone_mirror_scrcpy.sh [опции]
#
# Опции:
#   --record FILE   Записывать видео в файл
#   --no-audio      Без звука
#   --size SIZE     Максимальный размер (например, 1024)
#

set -e

# Проверяем наличие scrcpy
if ! command -v scrcpy &> /dev/null; then
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║  scrcpy не установлен!                                           ║"
    echo "║                                                                  ║"
    echo "║  Установка:                                                      ║"
    echo "║    Ubuntu/Debian: sudo apt install scrcpy                        ║"
    echo "║    Fedora:        sudo dnf install scrcpy                        ║"
    echo "║    Arch:          sudo pacman -S scrcpy                          ║"
    echo "║    macOS:         brew install scrcpy                            ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    exit 1
fi

# Проверяем подключение устройства
DEVICE_COUNT=$(adb devices | grep -c "device$" || true)
if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║  Телефон не подключен!                                           ║"
    echo "║                                                                  ║"
    echo "║  1. Включите 'Отладка по USB' на телефоне                        ║"
    echo "║  2. Подключите телефон по USB                                    ║"
    echo "║  3. Подтвердите отладку в диалоге на телефоне                    ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    exit 1
fi

# Парсим аргументы
RECORD_FILE=""
NO_AUDIO=false
MAX_SIZE=1024
WINDOW_TITLE="Прогулкин"

while [[ $# -gt 0 ]]; do
    case $1 in
        --record)
            RECORD_FILE="$2"
            shift 2
            ;;
        --no-audio)
            NO_AUDIO=true
            shift
            ;;
        --size)
            MAX_SIZE="$2"
            shift 2
            ;;
        --title)
            WINDOW_TITLE="$2"
            shift 2
            ;;
        *)
            echo "Неизвестный параметр: $1"
            exit 1
            ;;
    esac
done

# Формируем команду
CMD="scrcpy --max-size=$MAX_SIZE --window-title='$WINDOW_TITLE'"

if [ -n "$RECORD_FILE" ]; then
    CMD="$CMD --record='$RECORD_FILE'"
    echo "📹 Запись будет сохранена в: $RECORD_FILE"
fi

if [ "$NO_AUDIO" = true ]; then
    CMD="$CMD --no-audio"
fi

echo "🚀 Запуск зеркалирования..."
echo "   Команда: $CMD"
echo ""
echo "Горячие клавиши scrcpy:"
echo "  Ctrl+O - выключить экран телефона"
echo "  Ctrl+S - скриншот"
echo "  Ctrl+R - запись экрана (переключение)"
echo "  Ctrl+X - закрыть"
echo ""

eval $CMD
