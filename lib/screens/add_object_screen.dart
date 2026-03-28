import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../models/map_objects/map_objects.dart';
import '../providers/map_object_provider.dart';
import '../services/user_id_service.dart';
import '../services/photo_compression_service.dart';

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
  
  // Поля для заметки об интересном месте
  InterestCategory _interestCategory = InterestCategory.other;
  final _interestTitleController = TextEditingController();
  final _interestDescriptionController = TextEditingController();
  final List<Uint8List> _selectedPhotos = [];
  final List<String> _photoIds = [];
  bool _showContact = false;
  final _photoCompressionService = PhotoCompressionService();
  
  // Поля для напоминалки
  ReminderCharacterType _characterType = ReminderCharacterType.kopatych;
  final _reminderTextController = TextEditingController();
  double _triggerRadius = 50;
  
  @override
  void dispose() {
    _trashDescriptionController.dispose();
    _secretTitleController.dispose();
    _secretContentController.dispose();
    _interestTitleController.dispose();
    _interestDescriptionController.dispose();
    _reminderTextController.dispose();
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Выбор типа объекта
              Text(
                'Тип объекта',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildTypeSelector(),
              
              const SizedBox(height: 24),
              
              // Форма в зависимости от типа
              switch (_selectedTypeIndex) {
                0 => _buildTrashMonsterForm(),
                1 => _buildSecretMessageForm(),
                2 => _buildInterestNoteForm(),
                3 => _buildReminderForm(),
                _ => _buildTrashMonsterForm(),
              },
              
              const SizedBox(height: 16),
              
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
        ],
        selected: {_selectedTypeIndex},
        onSelectionChanged: (Set<int> selection) {
          setState(() {
            _selectedTypeIndex = selection.first;
          });
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
        const SizedBox(height: 8),
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
        
        const SizedBox(height: 16),
        
        Text(
          'Количество',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
        
        const SizedBox(height: 16),
        
        Text(
          'Описание (необязательно)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _trashDescriptionController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Опишите, что именно вы видите...',
            border: OutlineInputBorder(),
          ),
        ),
        
        const SizedBox(height: 16),
        
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
        const SizedBox(height: 8),
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
        
        const SizedBox(height: 16),
        
        Text(
          'Название',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
        
        const SizedBox(height: 16),
        
        Text(
          'Содержимое',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
        
        const SizedBox(height: 16),
        
        Text(
          'Радиус разблокировки: ${_unlockRadius.toInt()} м',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
        
        const SizedBox(height: 8),
        
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
        const SizedBox(height: 8),
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
        
        const SizedBox(height: 16),
        
        Text(
          'Название',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
        
        const SizedBox(height: 16),
        
        Text(
          'Описание',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _interestDescriptionController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Расскажите подробнее об этом месте...',
            border: OutlineInputBorder(),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Фото
        Row(
          children: [
            Text(
              'Фото',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _pickPhotos,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Добавить'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        if (_selectedPhotos.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedPhotos.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _selectedPhotos[index],
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPhotos.removeAt(index);
                              if (index < _photoIds.length) {
                                _photoIds.removeAt(index);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        
        const SizedBox(height: 16),
        
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
        const SizedBox(height: 8),
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
        
        const SizedBox(height: 16),
        
        Text(
          'Текст напоминания',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
        
        const SizedBox(height: 16),
        
        Text(
          'Радиус срабатывания: ${_triggerRadius.toInt()} м',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
  
  /// Выбор фото
  Future<void> _pickPhotos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.bytes != null) {
            // Сжимаем фото
            final compressed = await _photoCompressionService.compressBytes(
              bytes: file.bytes!,
            );
            
            if (compressed.success && compressed.compressedBytes != null) {
              setState(() {
                _selectedPhotos.add(compressed.compressedBytes!);
                _photoIds.add(compressed.photoId!);
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при выборе фото: $e')),
        );
      }
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
          await mapObjectProvider.createTrashMonster(
            latitude: widget.latitude,
            longitude: widget.longitude,
            ownerId: widget.userInfo.id,
            ownerName: widget.userInfo.name,
            ownerReputation: widget.userInfo.reputation,
            trashType: _trashType,
            quantity: _trashQuantity,
            description: _trashDescriptionController.text,
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
          for (int i = 0; i < _selectedPhotos.length; i++) {
            await storage.savePhoto(
              id: _photoIds[i],
              webpData: _selectedPhotos[i].toList(),
              status: 'confirmed',
            );
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
            photoIds: _photoIds,
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
      }
      
      if (mounted) {
        Navigator.pop(context);
        final messages = [
          'Мусорный монстр создан!',
          'Секретное сообщение оставлено!',
          'Заметка добавлена!',
          'Напоминание создано!',
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
