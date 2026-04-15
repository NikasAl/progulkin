import 'package:flutter/material.dart';
import '../../models/map_objects/map_objects.dart';
import '../../config/constants.dart';

/// Данные формы секретного сообщения
class SecretMessageFormData {
  final SecretType secretType;
  final String title;
  final String content;
  final double unlockRadius;
  final bool isOneTime;

  const SecretMessageFormData({
    required this.secretType,
    required this.title,
    required this.content,
    required this.unlockRadius,
    required this.isOneTime,
  });
}

/// Форма создания секретного сообщения
class SecretMessageForm extends StatefulWidget {
  const SecretMessageForm({super.key});

  @override
  State<SecretMessageForm> createState() => SecretMessageFormState();
}

class SecretMessageFormState extends State<SecretMessageForm> {
  SecretType _secretType = SecretType.hint;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  double _unlockRadius = 50;
  bool _isOneTime = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Получить данные формы
  SecretMessageFormData getData() {
    return SecretMessageFormData(
      secretType: _secretType,
      title: _titleController.text,
      content: _contentController.text,
      unlockRadius: _unlockRadius,
      isOneTime: _isOneTime,
    );
  }

  /// Валидация формы
  bool validate() {
    return _titleController.text.isNotEmpty && _contentController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Тип секрета',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SecretType.values.map((type) => ChoiceChip(
            label: Text('${type.emoji} ${type.name}'),
            selected: _secretType == type,
            onSelected: (selected) {
              if (selected) setState(() => _secretType = type);
            },
          )).toList(),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        Text(
          'Название',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        TextFormField(
          controller: _titleController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Введите название';
            }
            return null;
          },
          decoration: const InputDecoration(
            hintText: 'Короткое название для отображения',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        Text(
          'Содержимое',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        TextFormField(
          controller: _contentController,
          maxLines: 5,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Введите содержимое';
            }
            return null;
          },
          decoration: const InputDecoration(
            hintText: 'Текст, который увидят только подойдя близко...',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        Text(
          'Радиус разблокировки: ${_unlockRadius.toInt()} м',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        Slider(
          value: _unlockRadius,
          min: 10,
          max: 200,
          divisions: 19,
          label: '${_unlockRadius.toInt()} м',
          onChanged: (value) {
            setState(() => _unlockRadius = value);
          },
        ),

        const SizedBox(height: UIConstants.itemSpacing),

        SwitchListTile(
          title: const Text('Одноразовое'),
          subtitle: const Text('Исчезнет после первого прочтения'),
          value: _isOneTime,
          onChanged: (value) {
            setState(() => _isOneTime = value);
          },
        ),
      ],
    );
  }
}
