import 'package:flutter/material.dart';
import '../../models/map_objects/map_objects.dart';
import '../../config/constants.dart';

/// Данные формы напоминания
class ReminderFormData {
  final ReminderCharacterType characterType;
  final String text;
  final double triggerRadius;

  const ReminderFormData({
    required this.characterType,
    required this.text,
    required this.triggerRadius,
  });
}

/// Форма создания напоминания
class ReminderForm extends StatefulWidget {
  const ReminderForm({super.key});

  @override
  State<ReminderForm> createState() => ReminderFormState();
}

class ReminderFormState extends State<ReminderForm> {
  ReminderCharacterType _characterType = ReminderCharacterType.kopatych;
  final _textController = TextEditingController();
  double _triggerRadius = 50;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Получить данные формы
  ReminderFormData getData() {
    return ReminderFormData(
      characterType: _characterType,
      text: _textController.text,
      triggerRadius: _triggerRadius,
    );
  }

  /// Валидация формы
  bool validate() {
    return _textController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Персонаж',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReminderCharacterType.values.map((char) => ChoiceChip(
            label: Text('${char.emoji} ${char.name}'),
            selected: _characterType == char,
            onSelected: (selected) {
              if (selected) setState(() => _characterType = char);
            },
          )).toList(),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        Text(
          'Текст напоминания',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        TextFormField(
          controller: _textController,
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Введите текст напоминания';
            }
            return null;
          },
          decoration: const InputDecoration(
            hintText: 'Например: "Купить молоко"',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        Text(
          'Радиус срабатывания: ${_triggerRadius.toInt()} м',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        Slider(
          value: _triggerRadius,
          min: 10,
          max: 500,
          divisions: 49,
          label: '${_triggerRadius.toInt()} м',
          onChanged: (value) {
            setState(() => _triggerRadius = value);
          },
        ),
        Text(
          'Напоминание сработает, когда вы приблизитесь к этому месту',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
