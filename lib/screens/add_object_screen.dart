import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/map_object_provider.dart';
import '../services/user_id_service.dart';
import '../config/constants.dart';
import '../widgets/photo_capture_widget.dart';
import '../utils/snackbar_helper.dart';
import 'add_object/add_object.dart';

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

  // Общие фото для монстра, заметки и места сбора
  final List<PhotoCaptureResult> _photos = [];

  // Ключи для доступа к состояниям форм
  final _trashMonsterFormKey = GlobalKey<TrashMonsterFormState>();
  final _secretMessageFormKey = GlobalKey<SecretMessageFormState>();
  final _interestNoteFormKey = GlobalKey<InterestNoteFormState>();
  final _reminderFormKey = GlobalKey<ReminderFormState>();
  final _foragingSpotFormKey = GlobalKey<ForagingSpotFormState>();

  void _onPhotoAdded(PhotoCaptureResult photo) {
    setState(() {
      _photos.add(photo);
    });
  }

  void _onPhotoRemoved(int index) {
    setState(() {
      _photos.removeAt(index);
    });
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
                0 => TrashMonsterForm(
                  key: _trashMonsterFormKey,
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                  photos: _photos,
                  onPhotoAdded: _onPhotoAdded,
                  onPhotoRemoved: _onPhotoRemoved,
                ),
                1 => SecretMessageForm(key: _secretMessageFormKey),
                2 => InterestNoteForm(
                  key: _interestNoteFormKey,
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                  userInfo: widget.userInfo,
                  photos: _photos,
                  onPhotoAdded: _onPhotoAdded,
                  onPhotoRemoved: _onPhotoRemoved,
                ),
                3 => ReminderForm(key: _reminderFormKey),
                4 => ForagingSpotForm(
                  key: _foragingSpotFormKey,
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                  photos: _photos,
                  onPhotoAdded: _onPhotoAdded,
                  onPhotoRemoved: _onPhotoRemoved,
                ),
                _ => TrashMonsterForm(
                  key: _trashMonsterFormKey,
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                  photos: _photos,
                  onPhotoAdded: _onPhotoAdded,
                  onPhotoRemoved: _onPhotoRemoved,
                ),
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

  /// Сохранить объект
  Future<void> _saveObject() async {
    // Валидация форм с валидацией
    if (_selectedTypeIndex == 1) {
      if (!_secretMessageFormKey.currentState!.validate()) return;
    } else if (_selectedTypeIndex == 2) {
      if (!_interestNoteFormKey.currentState!.validate()) return;
    } else if (_selectedTypeIndex == 3) {
      if (!_reminderFormKey.currentState!.validate()) return;
    }

    setState(() => _isLoading = true);

    try {
      final mapObjectProvider = context.read<MapObjectProvider>();

      switch (_selectedTypeIndex) {
        case 0:
          await _saveTrashMonster(mapObjectProvider);
          break;
        case 1:
          await _saveSecretMessage(mapObjectProvider);
          break;
        case 2:
          await _saveInterestNote(mapObjectProvider);
          break;
        case 3:
          await _saveReminder(mapObjectProvider);
          break;
        case 4:
          await _saveForagingSpot(mapObjectProvider);
          break;
      }

      if (mounted) {
        Navigator.pop(context, ObjectCreatedResult(typeIndex: _selectedTypeIndex));
        _showSuccessMessage();
      }
    } catch (e) {
      if (mounted) {
        context.showError('Ошибка: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveTrashMonster(MapObjectProvider provider) async {
    final data = _trashMonsterFormKey.currentState!.getData();
    final storage = provider.storage;
    final photoIds = await _savePhotos(storage);

    await provider.createTrashMonster(
      latitude: widget.latitude,
      longitude: widget.longitude,
      ownerId: widget.userInfo.id,
      ownerName: widget.userInfo.name,
      ownerReputation: widget.userInfo.reputation,
      trashType: data.trashType,
      quantity: data.quantity,
      description: data.description,
      photoIds: photoIds.isNotEmpty ? photoIds : null,
    );
  }

  Future<void> _saveSecretMessage(MapObjectProvider provider) async {
    final data = _secretMessageFormKey.currentState!.getData();

    await provider.createSecretMessage(
      latitude: widget.latitude,
      longitude: widget.longitude,
      ownerId: widget.userInfo.id,
      ownerName: widget.userInfo.name,
      ownerReputation: widget.userInfo.reputation,
      secretType: data.secretType,
      title: data.title,
      content: data.content,
      unlockRadius: data.unlockRadius,
      isOneTime: data.isOneTime,
    );
  }

  Future<void> _saveInterestNote(MapObjectProvider provider) async {
    final data = _interestNoteFormKey.currentState!.getData();
    final storage = provider.storage;
    final photoIds = await _savePhotos(storage);

    await provider.createInterestNote(
      latitude: widget.latitude,
      longitude: widget.longitude,
      ownerId: widget.userInfo.id,
      ownerName: widget.userInfo.name,
      ownerReputation: widget.userInfo.reputation,
      category: data.category,
      title: data.title,
      description: data.description,
      photoIds: photoIds,
      contactVisible: data.showContact,
    );
  }

  Future<void> _saveReminder(MapObjectProvider provider) async {
    final data = _reminderFormKey.currentState!.getData();

    await provider.createReminderCharacter(
      latitude: widget.latitude,
      longitude: widget.longitude,
      ownerId: widget.userInfo.id,
      ownerName: widget.userInfo.name,
      ownerReputation: widget.userInfo.reputation,
      characterType: data.characterType,
      reminderText: data.text,
      triggerRadius: data.triggerRadius,
    );
  }

  Future<void> _saveForagingSpot(MapObjectProvider provider) async {
    final data = _foragingSpotFormKey.currentState!.getData();
    final storage = provider.storage;
    final photoIds = await _savePhotos(storage);

    await provider.createForagingSpot(
      latitude: widget.latitude,
      longitude: widget.longitude,
      ownerId: widget.userInfo.id,
      ownerName: widget.userInfo.name,
      ownerReputation: widget.userInfo.reputation,
      category: data.category,
      itemTypeCode: data.itemTypeCode,
      quantity: data.quantity,
      season: data.season,
      notes: data.notes,
      photoIds: photoIds,
    );
  }

  Future<List<String>> _savePhotos(dynamic storage) async {
    final photoIds = <String>[];
    for (final photo in _photos) {
      await storage.savePhoto(
        id: photo.id,
        webpData: photo.bytes.toList(),
        status: 'confirmed',
      );
      photoIds.add(photo.id);
    }
    return photoIds;
  }

  void _showSuccessMessage() {
    final messages = [
      'Мусорный монстр создан!',
      'Секретное сообщение оставлено!',
      'Заметка добавлена!',
      'Напоминание создано!',
      'Место сбора отмечено!',
    ];
    context.showSuccess(messages[_selectedTypeIndex]);
  }
}
