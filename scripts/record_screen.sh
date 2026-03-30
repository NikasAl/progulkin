#!/bin/bash
#
# Скрипт для записи видео с области экрана
# Использует ffmpeg для захвата
#
# Установка ffmpeg:
#   Ubuntu/Debian: sudo apt install ffmpeg
#   Fedora:        sudo dnf install ffmpeg
#   Arch:          sudo pacman -S ffmpeg
#
# Использование:
#   ./record_screen.sh [опции]
#
# Опции:
#   --output FILE   Выходной файл (по умолчанию: video_YYYYMMDD_HHMMSS.mp4)
#   --region X,Y,W,H  Область захвата (пример: 100,100,400,800)
#   --fps FPS       Кадров в секунду (по умолчанию: 30)
#

set -e

# Значения по умолчанию
OUTPUT_FILE=""
REGION=""
FPS=30
DISPLAY=":0"

while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --fps)
            FPS="$2"
            shift 2
            ;;
        --display)
            DISPLAY="$2"
            shift 2
            ;;
        *)
            echo "Неизвестный параметр: $1"
            exit 1
            ;;
    esac
done

# Генерируем имя файла если не указано
if [ -z "$OUTPUT_FILE" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OUTPUT_DIR="/home/z/my-project/progulkin/videos"
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_FILE="$OUTPUT_DIR/progulkin_demo_$TIMESTAMP.mp4"
fi

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  Запись экрана                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Выходной файл: $OUTPUT_FILE"
echo "🎬 FPS: $FPS"

# Проверяем ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ ffmpeg не установлен!"
    echo "   Установка: sudo apt install ffmpeg"
    exit 1
fi

# Определяем захват
if [ -n "$REGION" ]; then
    # Захват области
    IFS=',' read -r X Y W H <<< "$REGION"
    echo "📐 Область: x=$X, y=$Y, ширина=$W, высота=$H"
    
    ffmpeg -f x11grab -draw_mouse 1 \
        -framerate $FPS \
        -video_size ${W}x${H} \
        -i ${DISPLAY}+${X},${Y} \
        -c:v libx264 -preset ultrafast -crf 22 \
        -pix_fmt yuv420p \
        "$OUTPUT_FILE"
else
    # Захват всего экрана с выбором области мышью
    echo ""
    echo "🎯 Выберите область для записи мышью..."
    echo "   (будет показан прямоугольник выбора)"
    echo ""
    
    # Используем slop для выбора области (если установлен)
    if command -v slop &> /dev/null; then
        SLOP=$(slop -f "%x %y %w %h" -b 3 -c 1,0,0,1)
        read -r X Y W H <<< "$SLOP"
        echo "📐 Выбрана область: x=$X, y=$Y, ширина=$W, высота=$H"
        
        ffmpeg -f x11grab -draw_mouse 1 \
            -framerate $FPS \
            -video_size ${W}x${H} \
            -i ${DISPLAY}+${X},${Y} \
            -c:v libx264 -preset ultrafast -crf 22 \
            -pix_fmt yuv420p \
            "$OUTPUT_FILE"
    else
        echo "💡 Совет: установите slop для выбора области мышью"
        echo "   sudo apt install slop"
        echo ""
        echo "📹 Запись всего экрана..."
        
        # Получаем размер экрана
        SCREEN_SIZE=$(xdpyinfo | awk '/dimensions/{print $2}')
        echo "📐 Размер экрана: $SCREEN_SIZE"
        
        ffmpeg -f x11grab -draw_mouse 1 \
            -framerate $FPS \
            -i ${DISPLAY} \
            -c:v libx264 -preset ultrafast -crf 22 \
            -pix_fmt yuv420p \
            "$OUTPUT_FILE"
    fi
fi
