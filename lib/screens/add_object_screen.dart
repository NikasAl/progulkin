import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/map_objects/map_objects.dart';
import '../providers/map_object_provider.dart';
import '../services/user_id_service.dart';
import '../config/constants.dart';
import '../widgets/photo_capture_widget.dart';

/// Результат создания объекта
class ObjectCreatedResult {
  final int typeIndex;
  final int points;

  const ObjectCreatedResult({required this.typeIndex, this.points = PointsConstants.objectCreationPoints});
}

/// Экран добавления нового объекта на карту
class AddObjectScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final UserInfo userInfo;

  const AddObjectScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.userInfo,
  });

  @override
  State<AddObjectScreen> createState() => _AddObjectScreenState();
}

class _AddObjectScreenState extends State<AddObjectScreen> {
  int _selectedTypeIndex = 0;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Поля для мусорного монстра
  TrashType _trashType = TrashType.mixed;
  TrashQuantity _trashQuantity = TrashQuantity.few;
  final _trashDescriptionController = TextEditingController();

  // Поля для секретного сообщения
  final _secretTitleController = TextEditingController();
  final _secretContentController = TextEditingController();
  SecretType _secretType = SecretType.hint;
  double _unlockRadius = 50;
  bool _isOneTime = false;

  // Поля для заметки об интересном месте (и фото для монстра)
  InterestCategory _interestCategory = InterestCategory.other;
  final _interestTitleController = TextEditingController();
  final _interestDescriptionController = TextEditingController();
  final List<PhotoCaptureResult> _photos = [];
  bool _showContact = false;

  // Поля для напоминалки
  ReminderCharacterType _characterType = ReminderCharacterType.kopatych;
  final _reminderTextController = TextEditingController();
  double _triggerRadius = 50;

  // Поля для места сбора (грибы/ягоды)
  ForagingCategory _foragingCategory = ForagingCategory.mushroom;
  String _foragingItemTypeCode = 'white'; // По умолчанию белый гриб
  ForagingQuantity _foragingQuantity = ForagingQuantity.some;
  ForagingSeason _foragingSeason = ForagingSeason.summer;
  final _foragingNotesController = TextEditingController();

  @override
  void dispose() {
    _trashDescriptionController.dispose();
    _secretTitleController.dispose();
    _secretContentController.dispose();
    _interestTitleController.dispose();
    _interestDescriptionController.dispose();
    _reminderTextController.dispose();
    _foragingNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить объект'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveObject,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Сохранить'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(UIConstants.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Выбор типа объекта
              Text(
                'Тип объекта',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: UIConstants.itemSpacing),
              _buildTypeSelector(),

              const SizedBox(height: 24),

              // Форма в зависимости от типа
              switch (_selectedTypeIndex) {
                0 => _buildTrashMonsterForm(),
                1 => _buildSecretMessageForm(),
                2 => _buildInterestNoteForm(),
                3 => _buildReminderForm(),
                4 => _buildForagingSpotForm(),
                _ => _buildTrashMonsterForm(),
              },

              const SizedBox(height: UIConstants.sectionSpacing),

              // Координаты
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Селектор типа объекта
  Widget _buildTypeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            label: Text('Монстр'),
            icon: Text('👹'),
          ),
          ButtonSegment(
            value: 1,
            label: Text('Секрет'),
            icon: Text('📜'),
          ),
          ButtonSegment(
            value: 2,
            label: Text('Заметка'),
            icon: Text('📍'),
          ),
          ButtonSegment(
            value: 3,
            label: Text('Напоминание'),
            icon: Text('🔔'),
          ),
          ButtonSegment(
            value: 4,
            label: Text('Сбор'),
            icon: Text('🍄'),
          ),
        ],
        selected: {_selectedTypeIndex},
        onSelectionChanged: (Set<int> selection) {
          final newIndex = selection.first;
          if (newIndex != _selectedTypeIndex) {
            setState(() {
              _selectedTypeIndex = newIndex;
              // Очищаем фото при смене типа
              _photos.clear();
            });
          }
        },
      ),
    );
  }

  /// Форма для мусорного монстра
  Widget _buildTrashMonsterForm() {
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
          controller: _trashDescriptionController,
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
          photos: _photos,
          onPhotoAdded: (photo) {
            setState(() {
              _photos.add(photo);
            });
          },
          onPhotoRemoved: (index) {
            setState(() {
              _photos.removeAt(index);
            });
          },
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        // Предпросмотр класса монстра
        _buildMonsterPreview(),
      ],
    );
  }

  /// Предпросмотр класса монстра
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

  /// Форма для секретного сообщения
  Widget _buildSecretMessageForm() {
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
          controller: _secretTitleController,
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
          controller: _secretContentController,
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

  /// Форма для заметки об интересном месте
  Widget _buildInterestNoteForm() {
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
            selected: _interestCategory == cat,
            onSelected: (selected) {
              if (selected) setState(() => _interestCategory = cat);
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
          controller: _interestTitleController,
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
          controller: _interestDescriptionController,
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
          photos: _photos,
          onPhotoAdded: (photo) {
            setState(() {
              _photos.add(photo);
            });
          },
          onPhotoRemoved: (index) {
            setState(() {
              _photos.removeAt(index);
            });
          },
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

        if (_showContact)
          Card(
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
          ),
      ],
    );
  }

  /// Форма для напоминалки
  Widget _buildReminderForm() {
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
          controller: _reminderTextController,
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

  /// Форма для места сбора (грибы, ягоды, орехи, травы)
  Widget _buildForagingSpotForm() {
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
            selected: _foragingCategory == cat,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _foragingCategory = cat;
                  // Сбрасываем тип на первый из новой категории
                  _foragingItemTypeCode = _getDefaultItemType(cat);
                });
              }
            },
          )).toList(),
        ),

        const SizedBox(height: UIConstants.sectionSpacing),

        // Динамический выбор типа в зависимости от категории
        Text(
          _getTypeLabelForCategory(_foragingCategory),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UIConstants.itemSpacing),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getItemTypesForCategory(_foragingCategory).map((item) => ChoiceChip(
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
            selected: _foragingItemTypeCode == item['code'],
            onSelected: (selected) {
              if (selected) setState(() => _foragingItemTypeCode = item['code'] as String);
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
            selected: _foragingQuantity == qty,
            onSelected: (selected) {
              if (selected) setState(() => _foragingQuantity = qty);
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
            selected: _foragingSeason == season,
            onSelected: (selected) {
              if (selected) setState(() => _foragingSeason = season);
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
          controller: _foragingNotesController,
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
          photos: _photos,
          onPhotoAdded: (photo) {
            setState(() {
              _photos.add(photo);
            });
          },
          onPhotoRemoved: (index) {
            setState(() {
              _photos.removeAt(index);
            });
          },
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

  /// Сохранить объект
  Future<void> _saveObject() async {
    // Валидация
    if (_selectedTypeIndex == 1 || _selectedTypeIndex == 2 || _selectedTypeIndex == 3) {
      if (!_formKey.currentState!.validate()) return;
    }

    setState(() => _isLoading = true);

    try {
      final mapObjectProvider = context.read<MapObjectProvider>();

      switch (_selectedTypeIndex) {
        case 0:
          // Создаём мусорного монстра
          // Сначала сохраняем фото
          final storage = mapObjectProvider.storage;
          final photoIds = <String>[];
          for (final photo in _photos) {
            await storage.savePhoto(
              id: photo.id,
              webpData: photo.bytes.toList(),
              status: 'confirmed',
            );
            photoIds.add(photo.id);
          }

          await mapObjectProvider.createTrashMonster(
            latitude: widget.latitude,
            longitude: widget.longitude,
            ownerId: widget.userInfo.id,
            ownerName: widget.userInfo.name,
            ownerReputation: widget.userInfo.reputation,
            trashType: _trashType,
            quantity: _trashQuantity,
            description: _trashDescriptionController.text,
            photoIds: photoIds.isNotEmpty ? photoIds : null,
          );
          break;

        case 1:
          // Создаём секретное сообщение
          await mapObjectProvider.createSecretMessage(
            latitude: widget.latitude,
            longitude: widget.longitude,
            ownerId: widget.userInfo.id,
            ownerName: widget.userInfo.name,
            ownerReputation: widget.userInfo.reputation,
            secretType: _secretType,
            title: _secretTitleController.text,
            content: _secretContentController.text,
            unlockRadius: _unlockRadius,
            isOneTime: _isOneTime,
          );
          break;

        case 2:
          // Создаём заметку об интересном месте
          // Сначала сохраняем фото
          final storage = mapObjectProvider.storage;
          final photoIds = <String>[];
          for (final photo in _photos) {
            await storage.savePhoto(
              id: photo.id,
              webpData: photo.bytes.toList(),
              status: 'confirmed',
            );
            photoIds.add(photo.id);
          }

          await mapObjectProvider.createInterestNote(
            latitude: widget.latitude,
            longitude: widget.longitude,
            ownerId: widget.userInfo.id,
            ownerName: widget.userInfo.name,
            ownerReputation: widget.userInfo.reputation,
            category: _interestCategory,
            title: _interestTitleController.text,
            description: _interestDescriptionController.text,
            photoIds: photoIds,
            contactVisible: _showContact,
          );
          break;

        case 3:
          // Создаём напоминалку
          await mapObjectProvider.createReminderCharacter(
            latitude: widget.latitude,
            longitude: widget.longitude,
            ownerId: widget.userInfo.id,
            ownerName: widget.userInfo.name,
            ownerReputation: widget.userInfo.reputation,
            characterType: _characterType,
            reminderText: _reminderTextController.text,
            triggerRadius: _triggerRadius,
          );
          break;

        case 4:
          // Создаём место сбора
          // Сначала сохраняем фото
          final foragingStorage = mapObjectProvider.storage;
          final foragingPhotoIds = <String>[];
          for (final photo in _photos) {
            await foragingStorage.savePhoto(
              id: photo.id,
              webpData: photo.bytes.toList(),
              status: 'confirmed',
            );
            foragingPhotoIds.add(photo.id);
          }

          await mapObjectProvider.createForagingSpot(
            latitude: widget.latitude,
            longitude: widget.longitude,
            ownerId: widget.userInfo.id,
            ownerName: widget.userInfo.name,
            ownerReputation: widget.userInfo.reputation,
            category: _foragingCategory,
            itemTypeCode: _foragingItemTypeCode,
            quantity: _foragingQuantity,
            season: _foragingSeason,
            notes: _foragingNotesController.text,
            photoIds: foragingPhotoIds,
          );
          break;
      }

      if (mounted) {
        // Возвращаем результат создания
        Navigator.pop(context, ObjectCreatedResult(typeIndex: _selectedTypeIndex));
        final messages = [
          'Мусорный монстр создан!',
          'Секретное сообщение оставлено!',
          'Заметка добавлена!',
          'Напоминание создано!',
          'Место сбора отмечено!',
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messages[_selectedTypeIndex]),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
