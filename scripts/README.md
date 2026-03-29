# Скрипты для записи видеообзора

## Быстрый старт

### 1. Подготовка телефона
```
1. Включите "Отладка по USB" в настройках телефона:
   Настройки → Для разработчиков → Отладка по USB

2. Подключите телефон к компьютеру по USB

3. Подтвердите отладку в диалоге на телефоне
```

### 2. Установка зависимостей

**Ubuntu/Debian:**
```bash
# ADB
sudo apt install android-tools-adb

# Python зависимости для зеркалирования
sudo apt install python3-tk python3-pil python3-pil.imagetk

# (Опционально) scrcpy для плавного стриминга
sudo apt install scrcpy

# (Опционально) slop для выбора области записи мышью
sudo apt install slop

# ffmpeg для записи
sudo apt install ffmpeg
```

### 3. Запуск зеркалирования

**Вариант A: Python скрипт (рекомендуется)**
```bash
python3 phone_mirror.py --interval-ms 300 --scale 0.5
```

**Вариант B: scrcpy (более плавно, но требует установки)**
```bash
bash phone_mirror_scrcpy.sh
```

### 4. Запись видео

В отдельном терминале:
```bash
# С выбором области мышью (нужен slop)
bash record_screen.sh --output demo.mp4

# С указанием конкретной области
bash record_screen.sh --region 1520,100,400,800 --output demo.mp4
```

## Скрипты

### phone_mirror.py
Зеркалирование экрана телефона через ADB.

**Опции:**
- `--interval-ms` — интервал обновления в мс (по умолчанию 500)
- `--scale` — масштаб отображения (по умолчанию 0.5 = 50%)
- `--title` — заголовок окна

**Примеры:**
```bash
# Плавное обновление (300мс)
python3 phone_mirror.py --interval-ms 300

# Больший размер окна
python3 phone_mirror.py --scale 0.7

# Свой заголовок
python3 phone_mirror.py --title "Демо Прогулкина"
```

### phone_mirror_scrcpy.sh
Зеркалирование через scrcpy (более продвинутый вариант).

**Опции:**
- `--record FILE` — записывать в файл
- `--no-audio` — без звука
- `--size SIZE` — макс. размер (по умолчанию 1024)

**Примеры:**
```bash
# Просто зеркалирование
bash phone_mirror_scrcpy.sh

# С записью
bash phone_mirror_scrcpy.sh --record video.mp4

# Без звука, меньший размер
bash phone_mirror_scrcpy.sh --no-audio --size 800
```

### record_screen.sh
Запись области экрана через ffmpeg.

**Опции:**
- `--output FILE` — выходной файл
- `--region X,Y,W,H` — координаты области
- `--fps FPS` — кадров в секунду (по умолчанию 30)

**Примеры:**
```bash
# С выбором области мышью (нужен slop)
bash record_screen.sh

# Конкретная область (X=100, Y=200, W=400, H=800)
bash record_screen.sh --region 100,200,400,800

# Своё имя файла и FPS
bash record_screen.sh --output my_demo.mp4 --fps 60
```

### demo_setup.sh
Главный скрипт для подготовки к записи.

**Режимы:**
- `adb` — использовать Python скрипт (по умолчанию)
- `scrcpy` — использовать scrcpy

**Примеры:**
```bash
# По умолчанию (adb + Python)
bash demo_setup.sh

# Через scrcpy
bash demo_setup.sh scrcpy
```

## Решение проблем

### "adb не найден"
```bash
sudo apt install android-tools-adb
```

### "Телефон не подключен"
1. Проверьте кабель USB
2. Включите "Отладка по USB" на телефоне
3. На телефоне появится диалог — нажмите "Разрешить"

### "Таймаут захвата экрана"
- Попробуйте перезапустить adb: `adb kill-server && adb start-server`
- Проверьте разрешение на отладку на телефоне

### Медленное обновление
- Уменьшите `--interval-ms` (минимум 100)
- Используйте scrcpy вместо Python скрипта

### Видео не записывается
- Установите ffmpeg: `sudo apt install ffmpeg`
- Проверьте права на запись в директорию

## Структура файлов

```
scripts/
├── demo_setup.sh          # Главный скрипт запуска
├── phone_mirror.py        # Python зеркалирование
├── phone_mirror_scrcpy.sh # scrcpy обёртка
├── record_screen.sh       # Запись экрана
└── README.md              # Этот файл

docs/
└── VIDEO_SCRIPT.md        # Сценарий видеообзора

videos/                    # Директория для записей (создаётся автоматически)
└── progulkin_demo_*.mp4
```
