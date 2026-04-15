import 'package:flutter/material.dart';
import '../../models/map_objects/map_objects.dart';
import '../../config/constants.dart';
import '../../widgets/photo_capture_widget.dart';

/// Данные формы места сбора
class ForagingSpotFormData {
  final ForagingCategory category;
  final String itemTypeCode;
  final ForagingQuantity quantity;
  final ForagingSeason season;
  final String notes;
  final List<PhotoCaptureResult> photos;

  const ForagingSpotFormData({
    required this.category,
    required this.itemTypeCode,
    required this.quantity,
    required this.season,
    required this.notes,
    required this.photos,
  });
}

/// Форма создания места сбора (грибы, ягоды, орехи, травы)
class ForagingSpotForm extends StatefulWidget {
  final double latitude;
  final double longitude;
  final List<PhotoCaptureResult> photos;
  final void Function(PhotoCaptureResult) onPhotoAdded;
  final void Function(int) onPhotoRemoved;

  const ForagingSpotForm({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.photos,
    required this.onPhotoAdded,
    required this.onPhotoRemoved,
  });

  @override
  State<ForagingSpotForm> createState() => ForagingSpotFormState();
}

class ForagingSpotFormState extends State<ForagingSpotForm> {
  ForagingCategory _category = ForagingCategory.mushroom;
  String _itemTypeCode = 'white'; // По умолчанию белый гриб
  ForagingQuantity _quantity = ForagingQuantity.some;
  ForagingSeason _season = ForagingSeason.summer;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Получить данные формы
  ForagingSpotFormData getData() {
    return ForagingSpotFormData(
      category: _category,
      itemTypeCode: _itemTypeCode,
      quantity: _quantity,
      season: _season,
      notes: _notesController.text,
      photos: widget.photos,
    );
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
          children: ForagingCategory.values.map((cat) => ChoiceChip(
            label: Text('${cat.emoji} ${cat.name}'),
            selected: _category == cat,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _category = cat;
                  _itemTypeCode = _getDefaultItemType(cat);
                });
              }
            },
          )).toList(),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        // Динамический выбор типа в зависимости от категории
        Text(
          _getTypeLabelForCategory(_category),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getItemTypesForCategory(_category).map((item) => ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  item['assetPath'] as String,
                  width: 20,
                  height: 20,
                  errorBuilder: (_, __, ___) => Text(item['emoji'] as String),
                ),
                const SizedBox(width: 4),
                Text(item['name'] as String),
              ],
            ),
            selected: _itemTypeCode == item['code'],
            onSelected: (selected) {
              if (selected) setState(() => _itemTypeCode = item['code'] as String);
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
          children: ForagingQuantity.values.map((qty) => ChoiceChip(
            label: Text('${qty.name} (${qty.range})'),
            selected: _quantity == qty,
            onSelected: (selected) {
              if (selected) setState(() => _quantity = qty);
            },
          )).toList(),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        Text(
          'Сезон',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ForagingSeason.values.map((season) => ChoiceChip(
            label: Text('${season.emoji} ${season.name}'),
            selected: _season == season,
            onSelected: (selected) {
              if (selected) setState(() => _season = season);
            },
          )).toList(),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        Text(
          'Заметки (необязательно)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Например: "Растут под ёлками, много маслят"',
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

        // Предупреждение о безопасности
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Собирайте только те грибы и ягоды, в которых уверены. Некоторые виды могут быть опасны!',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Получить список типов для категории
  List<Map<String, dynamic>> _getItemTypesForCategory(ForagingCategory category) {
    switch (category) {
      case ForagingCategory.mushroom:
        return MushroomType.values.map((m) => {
          'code': m.code,
          'name': m.name,
          'emoji': m.emoji,
          'assetPath': m.assetPath,
        }).toList();
      case ForagingCategory.berry:
        return BerryType.values.map((b) => {
          'code': b.code,
          'name': b.name,
          'emoji': b.emoji,
          'assetPath': b.assetPath,
        }).toList();
      case ForagingCategory.nut:
        return NutType.values.map((n) => {
          'code': n.code,
          'name': n.name,
          'emoji': n.emoji,
          'assetPath': n.assetPath,
        }).toList();
      case ForagingCategory.herb:
        return HerbType.values.map((h) => {
          'code': h.code,
          'name': h.name,
          'emoji': h.emoji,
          'assetPath': h.assetPath,
        }).toList();
    }
  }

  /// Получить название для типа в категории
  String _getTypeLabelForCategory(ForagingCategory category) {
    switch (category) {
      case ForagingCategory.mushroom:
        return 'Вид грибов';
      case ForagingCategory.berry:
        return 'Вид ягод';
      case ForagingCategory.nut:
        return 'Вид орехов';
      case ForagingCategory.herb:
        return 'Вид трав';
    }
  }

  /// Получить тип по умолчанию для категории
  String _getDefaultItemType(ForagingCategory category) {
    switch (category) {
      case ForagingCategory.mushroom:
        return MushroomType.white.code;
      case ForagingCategory.berry:
        return BerryType.blueberry.code;
      case ForagingCategory.nut:
        return NutType.hazelnut.code;
      case ForagingCategory.herb:
        return HerbType.nettle.code;
    }
  }
}
