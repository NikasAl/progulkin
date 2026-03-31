import 'package:flutter/material.dart';

/// Экран политики конфиденциальности
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Политика конфиденциальности'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader('Политика конфиденциальности приложения «Прогулкин»'),
            SizedBox(height: 8),
            _DateText('Последнее обновление: 31 марта 2026 г.'),
            SizedBox(height: 24),

            _SectionHeader('1. Общие положения'),
            SizedBox(height: 8),
            _BodyText(
              'Настоящая Политика конфиденциальности определяет порядок обработки и защиты '
              'информации пользователей мобильного приложения «Прогулкин» (далее — Приложение).',
            ),
            SizedBox(height: 12),
            _BodyText(
              'Используя Приложение, вы соглашаетесь с условиями данной Политики конфиденциальности. '
              'Если вы не согласны с условиями Политики, пожалуйста, не используйте Приложение.',
            ),
            SizedBox(height: 24),

            _SectionHeader('2. Какие данные мы собираем'),
            SizedBox(height: 8),
            _BodyText(
              'Приложение «Прогулкин» работает полностью офлайн и не требует регистрации. '
              'Мы не собираем персональные данные пользователей.',
            ),
            SizedBox(height: 12),
            _SubHeader('Данные, хранящиеся на устройстве:'),
            SizedBox(height: 8),
            _BulletItem('Уникальный идентификатор устройства (генерируется автоматически)'),
            _BulletItem('Отображаемое имя пользователя (задаётся вами)'),
            _BulletItem('История прогулок (маршруты, статистика)'),
            _BulletItem('Объекты на карте, созданные вами'),
            _BulletItem('Фотографии, сделанные в приложении'),
            _BulletItem('Настройки приложения'),
            SizedBox(height: 12),
            _BodyText(
              'Все эти данные хранятся исключительно на вашем устройстве и не передаются '
              'на внешние серверы.',
            ),
            SizedBox(height: 24),

            _SectionHeader('3. Геолокация'),
            SizedBox(height: 8),
            _BodyText(
              'Приложение использует данные о местоположении устройства для следующих целей:',
            ),
            SizedBox(height: 8),
            _BulletItem('Запись маршрутов прогулок'),
            _BulletItem('Отображение вашего местоположения на карте'),
            _BulletItem('Создание объектов на карте в текущем месте'),
            _BulletItem('Гео-напоминания при приближении к заданным местам'),
            SizedBox(height: 12),
            _BodyText(
              'Данные о местоположении используются только в момент активной прогулки '
              'или при создании объектов. История местоположений хранится только на вашем устройстве.',
            ),
            SizedBox(height: 24),

            _SectionHeader('4. P2P-синхронизация'),
            SizedBox(height: 8),
            _BodyText(
              'Приложение поддерживает децентрализованную синхронизацию данных между '
              'устройствами пользователей без использования центрального сервера.',
            ),
            SizedBox(height: 12),
            _SubHeader('Что передаётся при синхронизации:'),
            SizedBox(height: 8),
            _BulletItem('Объекты, созданные вами на карте'),
            _BulletItem('Ваш отображаемое имя и идентификатор'),
            _BulletItem('Фотографии к объектам (в сжатом формате WebP)'),
            SizedBox(height: 12),
            _SubHeader('Что НЕ передаётся:'),
            SizedBox(height: 8),
            _BulletItem('История ваших прогулок'),
            _BulletItem('Личные заметки и напоминания'),
            _BulletItem('Контактная информация'),
            SizedBox(height: 12),
            _BodyText(
              'P2P-синхронизация работает только в локальной сети или через интернет '
              'с использованием signaling-сервера, который только знакомит устройства '
              'и не хранит данные пользователей.',
            ),
            SizedBox(height: 24),

            _SectionHeader('5. Фотографии'),
            SizedBox(height: 8),
            _BodyText(
              'Фотографии, сделанные в приложении, используются для:',
            ),
            SizedBox(height: 8),
            _BulletItem('Добавления изображений к объектам на карте'),
            _BulletItem('Документирования мусорных объектов'),
            SizedBox(height: 12),
            _BodyText(
              'Фотографии автоматически сжимаются до формата WebP для экономии места '
              'и быстрой передачи. EXIF-данные (включая GPS-координаты) удаляются при сжатии. '
              'Фотографии хранятся в локальной базе данных на устройстве.',
            ),
            SizedBox(height: 24),

            _SectionHeader('6. Карта'),
            SizedBox(height: 8),
            _BodyText(
              'Приложение использует карты OpenStreetMap — бесплатный проект по созданию '
              'карт мира силами сообщества. Загрузка тайлов карт происходит с серверов '
              'OpenStreetMap Foundation.',
            ),
            SizedBox(height: 12),
            _BodyText(
              'При кэшировании карт для офлайн-использования тайлы загружаются один раз '
              'и сохраняются на вашем устройстве.',
            ),
            SizedBox(height: 24),

            _SectionHeader('7. Уведомления'),
            SizedBox(height: 8),
            _BodyText(
              'Приложение может отправлять локальные уведомления на ваше устройство:',
            ),
            SizedBox(height: 8),
            _BulletItem('Гео-напоминания при приближении к заданным местам'),
            _BulletItem('Уведомления о близлежащих объектах'),
            SizedBox(height: 12),
            _BodyText(
              'Все уведомления генерируются локально на устройстве и не требуют '
              'подключения к внешним серверам.',
            ),
            SizedBox(height: 24),

            _SectionHeader('8. Безопасность данных'),
            SizedBox(height: 8),
            _BodyText(
              'Мы применяем следующие меры для защиты ваших данных:',
            ),
            SizedBox(height: 8),
            _BulletItem('Все данные хранятся в локальной базе данных SQLite'),
            _BulletItem('Секретные сообщения шифруются перед сохранением'),
            _BulletItem('P2P-соединения защищены шифрованием'),
            _BulletItem('Фото сжимаются без сохранения метаданных'),
            SizedBox(height: 24),

            _SectionHeader('9. Удаление данных'),
            SizedBox(height: 8),
            _BodyText(
              'Вы можете удалить все свои данные в любой момент:',
            ),
            SizedBox(height: 8),
            _BulletItem('Через Настройки → Хранилище → Очистить всё'),
            _BulletItem('Удалив приложение с устройства'),
            SizedBox(height: 12),
            _BodyText(
              'При удалении приложения все данные безвозвратно удаляются с устройства.',
            ),
            SizedBox(height: 24),

            _SectionHeader('10. Права пользователя'),
            SizedBox(height: 8),
            _BodyText('Вы имеете право:'),
            SizedBox(height: 8),
            _BulletItem('Не предоставлять никаких персональных данных'),
            _BulletItem('Использовать приложение без регистрации'),
            _BulletItem('Отключить синхронизацию в настройках'),
            _BulletItem('Удалить все свои данные в любой момент'),
            _BulletItem('Экспортировать свои данные для резервного копирования'),
            SizedBox(height: 24),

            _SectionHeader('11. Детская аудитория'),
            SizedBox(height: 8),
            _BodyText(
              'Приложение не предназначено для детей младше 6 лет. '
              'Мы не собираем персональные данные детей. '
              'Родители могут контролировать использование приложения через '
              'системные настройки устройства.',
            ),
            SizedBox(height: 24),

            _SectionHeader('12. Изменения политики'),
            SizedBox(height: 8),
            _BodyText(
              'Мы можем обновлять данную Политику конфиденциальности. '
              'При существенных изменениях мы уведомим вас через приложение. '
              'Рекомендуем периодически проверять эту страницу.',
            ),
            SizedBox(height: 24),

            _SectionHeader('13. Контактная информация'),
            SizedBox(height: 8),
            _BodyText(
              'По вопросам, связанным с данной Политикой конфиденциальности, '
              'вы можете связаться с разработчиком:',
            ),
            SizedBox(height: 12),
            _ContactItem(
              icon: Icons.code,
              title: 'GitHub',
              value: 'github.com/NikasAl/progulkin',
            ),
            SizedBox(height: 24),

            _SectionHeader('14. Соответствие законодательству'),
            SizedBox(height: 8),
            _BodyText(
              'Приложение разработано с учётом требований:',
            ),
            SizedBox(height: 8),
            _BulletItem('Федерального закона № 152-ФЗ «О персональных данных»'),
            _BulletItem('Регламента хранения данных на территории РФ'),
            _BulletItem('Требований RuStore к приложениям'),
            SizedBox(height: 32),

            _Divider(),
            SizedBox(height: 16),
            _FooterText(
              'Приложение «Прогулкин» не собирает персональные данные пользователей. '
              'Ваши данные — только ваши.',
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String text;
  const _SubHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _DateText extends StatelessWidget {
  final String text;
  const _DateText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.grey[600],
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: Theme.of(context).textTheme.bodyMedium),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _ContactItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(color: Colors.grey[300]);
  }
}

class _FooterText extends StatelessWidget {
  final String text;
  const _FooterText(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
