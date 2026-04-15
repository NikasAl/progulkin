import 'package:flutter/material.dart';
import '../../models/map_objects/map_objects.dart';
import '../../services/user_id_service.dart';
import '../../config/constants.dart';
import '../../widgets/photo_capture_widget.dart';

/// Данные формы заметки об интересном месте
class InterestNoteFormData {
  final InterestCategory category;
  final String title;
  final String description;
  final List<PhotoCaptureResult> photos;
  final bool showContact;

  const InterestNoteFormData({
    required this.category,
    required this.title,
    required this.description,
    required this.photos,
    required this.showContact,
  });
}

/// Форма создания заметки об интересном месте
class InterestNoteForm extends StatefulWidget {
  final double latitude;
  final double longitude;
  final UserInfo userInfo;
  final List<PhotoCaptureResult> photos;
  final void Function(PhotoCaptureResult) onPhotoAdded;
  final void Function(int) onPhotoRemoved;

  const InterestNoteForm({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.userInfo,
    required this.photos,
    required this.onPhotoAdded,
    required this.onPhotoRemoved,
  });

  @override
  State<InterestNoteForm> createState() => InterestNoteFormState();
}

class InterestNoteFormState extends State<InterestNoteForm> {
  InterestCategory _category = InterestCategory.other;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _showContact = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Получить данные формы
  InterestNoteFormData getData() {
    return InterestNoteFormData(
      category: _category,
      title: _titleController.text,
      description: _descriptionController.text,
      photos: widget.photos,
      showContact: _showContact,
    );
  }

  /// Валидация формы
  bool validate() {
    return _titleController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Категория',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: InterestCategory.values.map((cat) => ChoiceChip(
            label: Text('${cat.emoji} ${cat.name}'),
            selected: _category == cat,
            onSelected: (selected) {
              if (selected) setState(() => _category = cat);
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
            hintText: 'Например: "Белки на этом дереве"',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        Text(
          'Описание',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Расскажите подробнее об этом месте...',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        // Фото
        PhotoCaptureWidget(
          targetLatitude: widget.latitude,
          targetLongitude: widget.longitude,
          photos: widget.photos,
          onPhotoAdded: widget.onPhotoAdded,
          onPhotoRemoved: widget.onPhotoRemoved,
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        // Показывать контакт
        SwitchListTile(
          title: const Text('Показывать мой контакт'),
          subtitle: const Text('Пользователи смогут связаться с вами'),
          value: _showContact,
          onChanged: (value) {
            setState(() => _showContact = value);
          },
        ),

        if (_showContact) _buildContactPreview(),
      ],
    );
  }

  Widget _buildContactPreview() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(widget.userInfo.name.isNotEmpty
                      ? widget.userInfo.name[0]
                      : '?'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userInfo.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Репутация: ${widget.userInfo.reputation}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Настройте профиль в настройках приложения, чтобы добавить ссылки на соцсети',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
