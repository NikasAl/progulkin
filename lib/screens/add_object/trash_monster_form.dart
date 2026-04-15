import 'package:flutter/material.dart';
import '../../models/map_objects/map_objects.dart';
import '../../config/constants.dart';
import '../../widgets/photo_capture_widget.dart';

/// Данные формы мусорного монстра
class TrashMonsterFormData {
  final TrashType trashType;
  final TrashQuantity quantity;
  final String description;
  final List<PhotoCaptureResult> photos;

  const TrashMonsterFormData({
    required this.trashType,
    required this.quantity,
    required this.description,
    required this.photos,
  });
}

/// Форма создания мусорного монстра
class TrashMonsterForm extends StatefulWidget {
  final double latitude;
  final double longitude;
  final List<PhotoCaptureResult> photos;
  final void Function(PhotoCaptureResult) onPhotoAdded;
  final void Function(int) onPhotoRemoved;

  const TrashMonsterForm({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.photos,
    required this.onPhotoAdded,
    required this.onPhotoRemoved,
  });

  @override
  State<TrashMonsterForm> createState() => TrashMonsterFormState();
}

class TrashMonsterFormState extends State<TrashMonsterForm> {
  TrashType _trashType = TrashType.mixed;
  TrashQuantity _trashQuantity = TrashQuantity.few;
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Получить данные формы
  TrashMonsterFormData getData() {
    return TrashMonsterFormData(
      trashType: _trashType,
      quantity: _trashQuantity,
      description: _descriptionController.text,
      photos: widget.photos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Тип мусора',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TrashType.values.map((type) => ChoiceChip(
            label: Text('${type.emoji} ${type.name}'),
            selected: _trashType == type,
            onSelected: (selected) {
              if (selected) setState(() => _trashType = type);
            },
          )).toList(),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        Text(
          'Количество',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TrashQuantity.values.map((qty) => ChoiceChip(
            label: Text(qty.name),
            selected: _trashQuantity == qty,
            onSelected: (selected) {
              if (selected) setState(() => _trashQuantity = qty);
            },
          )).toList(),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        Text(
          'Описание (необязательно)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Опишите, что именно вы видите...',
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

        // Предпросмотр класса монстра
        _buildMonsterPreview(),
      ],
    );
  }

  Widget _buildMonsterPreview() {
    int classLevel = 1;

    // Тип мусора влияет на сложность
    if (_trashType == TrashType.tires ||
        _trashType == TrashType.furniture ||
        _trashType == TrashType.construction) {
      classLevel += 2;
    } else if (_trashType == TrashType.electronics) {
      classLevel += 1;
    }

    // Количество влияет на класс
    if (_trashQuantity == TrashQuantity.many) {
      classLevel += 1;
    } else if (_trashQuantity == TrashQuantity.heap) {
      classLevel += 2;
    }

    classLevel = classLevel.clamp(1, 5);
    final monsterClass = MonsterClass.fromLevel(classLevel);
    final points = monsterClass.basePoints * _trashQuantity.estimatedCount;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(
              monsterClass.badge,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Класс: ${monsterClass.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Очки за уборку: $points'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
