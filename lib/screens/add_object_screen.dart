import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/map_objects/map_objects.dart';
import '../providers/map_object_provider.dart';
import '../services/user_id_service.dart';

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
  
  @override
  void dispose() {
    _trashDescriptionController.dispose();
    _secretTitleController.dispose();
    _secretContentController.dispose();
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
              SegmentedButton<int>(
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
                ],
                selected: {_selectedTypeIndex},
                onSelectionChanged: (Set<int> selection) {
                  setState(() {
                    _selectedTypeIndex = selection.first;
                  });
                },
              ),
              
              const SizedBox(height: 24),
              
              // Форма в зависимости от типа
              if (_selectedTypeIndex == 0)
                _buildTrashMonsterForm()
              else
                _buildSecretMessageForm(),
              
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
  
  /// Сохранить объект
  Future<void> _saveObject() async {
    if (_selectedTypeIndex == 1) {
      // Валидация для секретного сообщения
      if (!_formKey.currentState!.validate()) return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final mapObjectProvider = context.read<MapObjectProvider>();
      
      if (_selectedTypeIndex == 0) {
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
      } else {
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
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedTypeIndex == 0 
                  ? 'Мусорный монстр создан!' 
                  : 'Секретное сообщение оставлено!',
            ),
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
