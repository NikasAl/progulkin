#!/usr/bin/env python3
"""
Скрипт для отображения экрана Android-телефона на десктопе.
Требует adb (Android Debug Bridge) и включённую отладку по USB на телефоне.

Установка зависимостей:
    Ubuntu/Debian: sudo apt install android-tools-adb python3-tk python3-pil python3-pil.imagetk
    Fedora: sudo dnf install android-tools python3-tkinter python3-pillow
    Arch: sudo pacman -S android-tools tk python-pillow

Использование:
    python3 phone_mirror.py [опции]

Опции:
    --interval-ms МИЛЛИСЕКУНДЫ  Интервал обновления (по умолчанию 500мс)
    --scale МАСШТАБ            Масштаб отображения (по умолчанию 0.5 = 50%)
    --title ЗАГОЛОВОК          Заголовок окна
"""

import subprocess
import sys
import os
import tempfile
import time
from pathlib import Path

try:
    import tkinter as tk
    from PIL import Image, ImageTk
except ImportError as e:
    print(f"Ошибка: {e}")
    print("\nУстановите зависимости:")
    print("  Ubuntu/Debian: sudo apt install python3-tk python3-pil python3-pil.imagetk")
    print("  Fedora: sudo dnf install python3-tkinter python3-pillow")
    print("  Arch: sudo pacman -S tk python-pillow")
    sys.exit(1)


class PhoneMirror:
    def __init__(self, interval_ms=500, scale=0.5, title="Прогулкин - Экран телефона"):
        self.interval_ms = interval_ms
        self.scale = scale
        self.title = title
        self.root = None
        self.label = None
        self.last_image = None
        self.running = True
        
    def check_adb(self):
        """Проверка доступности adb и подключения устройства"""
        try:
            result = subprocess.run(
                ["adb", "version"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode != 0:
                return False, "adb не найден. Установите android-tools-adb"
        except FileNotFoundError:
            return False, """
╔══════════════════════════════════════════════════════════════════╗
║  adb не установлен!                                              ║
║                                                                  ║
║  Установка:                                                      ║
║    Ubuntu/Debian: sudo apt install android-tools-adb             ║
║    Fedora:        sudo dnf install android-tools                 ║
║    Arch:          sudo pacman -S android-tools                   ║
║                                                                  ║
║  После установки:                                                ║
║    1. Включите "Отладка по USB" в настройках телефона            ║
║       (Настройки -> Для разработчиков -> Отладка по USB)         ║
║    2. Подключите телефон к компьютеру по USB                     ║
║    3. Подтвердите отладку на телефоне                            ║
╚══════════════════════════════════════════════════════════════════╝
"""
            return False, "adb не установлен"
        except Exception as e:
            return False, f"Ошибка проверки adb: {e}"
        
        # Проверяем подключение устройства
        try:
            result = subprocess.run(
                ["adb", "devices"],
                capture_output=True, text=True, timeout=5
            )
            lines = result.stdout.strip().split('\n')
            devices = [l for l in lines[1:] if l.strip() and 'device' in l]
            if not devices:
                return False, """
╔══════════════════════════════════════════════════════════════════╗
║  Телефон не подключен!                                           ║
║                                                                  ║
║  1. Включите "Отладка по USB" на телефоне                        ║
║     (Настройки -> Для разработчиков -> Отладка по USB)           ║
║  2. Подключите телефон по USB                                    ║
║  3. Подтвердите отладку в диалоге на телефоне                    ║
║  4. Перезапустите скрипт                                         ║
╚══════════════════════════════════════════════════════════════════╝
"""
        except Exception as e:
            return False, f"Ошибка проверки устройств: {e}"
        
        return True, "OK"
    
    def capture_screen(self):
        """Захват экрана телефона через adb"""
        try:
            # Метод 1: screencap напрямую в stdout (быстрее)
            result = subprocess.run(
                ["adb", "exec-out", "screencap", "-p"],
                capture_output=True, timeout=10
            )
            
            if result.returncode == 0 and len(result.stdout) > 1000:
                return result.stdout
            
            # Метод 2: через временный файл на телефоне
            subprocess.run(
                ["adb", "shell", "screencap", "-p", "/sdcard/screenshot.png"],
                capture_output=True, timeout=10
            )
            
            result = subprocess.run(
                ["adb", "pull", "/sdcard/screenshot.png", "-"],
                capture_output=True, timeout=10
            )
            
            if result.returncode == 0 and len(result.stdout) > 1000:
                return result.stdout
                
            return None
        except subprocess.TimeoutExpired:
            print("Таймаут захвата экрана")
            return None
        except Exception as e:
            print(f"Ошибка захвата: {e}")
            return None
    
    def update_image(self):
        """Обновление изображения в окне"""
        if not self.running:
            return
            
        start_time = time.time()
        
        png_data = self.capture_screen()
        
        if png_data:
            try:
                # Загружаем PNG из памяти
                from io import BytesIO
                image = Image.open(BytesIO(png_data))
                
                # Масштабируем
                if self.scale != 1.0:
                    new_size = (int(image.width * self.scale), int(image.height * self.scale))
                    image = image.resize(new_size, Image.Resampling.LANCZOS)
                
                # Конвертируем для tkinter
                photo = ImageTk.PhotoImage(image)
                
                self.label.configure(image=photo, text="")
                self.label.image = photo  # Сохраняем ссылку
                self.last_image = photo
                
                # FPS в заголовке
                elapsed = time.time() - start_time
                fps = 1.0 / elapsed if elapsed > 0 else 0
                self.root.title(f"{self.title} ({fps:.1f} FPS)")
                
            except Exception as e:
                self.label.configure(text=f"Ошибка: {e}")
        
        # Планируем следующее обновление
        if self.running:
            self.root.after(self.interval_ms, self.update_image)
    
    def on_closing(self):
        """Обработчик закрытия окна"""
        self.running = False
        self.root.destroy()
    
    def run(self):
        """Запуск зеркалирования"""
        # Проверяем adb
        ok, msg = self.check_adb()
        if not ok:
            print(msg)
            return
        
        # Создаём окно
        self.root = tk.Tk()
        self.root.title(self.title)
        self.root.configure(bg='#1a1a2e')
        
        # Центрируем окно
        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        window_width = 400
        window_height = 800
        x = screen_width - window_width - 50
        y = (screen_height - window_height) // 2
        self.root.geometry(f"{window_width}x{window_height}+{x}+{y}")
        
        # Метка для изображения
        self.label = tk.Label(
            self.root, 
            text="Загрузка первого кадра...",
            bg='#1a1a2e',
            fg='white',
            font=('Arial', 12)
        )
        self.label.pack(expand=True, fill='both')
        
        # Обработчик закрытия
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        
        # Запускаем обновление
        self.root.after(100, self.update_image)
        
        # Главный цикл
        self.root.mainloop()


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Зеркалирование экрана Android на десктоп',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры:
  python3 phone_mirror.py                    # По умолчанию (500мс, масштаб 50%)
  python3 phone_mirror.py --interval-ms 200  # Обновление каждые 200мс
  python3 phone_mirror.py --scale 0.7        # Масштаб 70%
  python3 phone_mirror.py --title "Демо"     # Свой заголовок окна
"""
    )
    parser.add_argument('--interval-ms', type=int, default=500,
                        help='Интервал обновления в миллисекундах (по умолчанию 500)')
    parser.add_argument('--scale', type=float, default=0.5,
                        help='Масштаб отображения (по умолчанию 0.5 = 50%%)')
    parser.add_argument('--title', type=str, default='Прогулкин - Экран телефона',
                        help='Заголовок окна')
    
    args = parser.parse_args()
    
    mirror = PhoneMirror(
        interval_ms=args.interval_ms,
        scale=args.scale,
        title=args.title
    )
    mirror.run()


if __name__ == '__main__':
    main()
