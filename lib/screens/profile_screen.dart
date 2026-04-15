import 'package:flutter/material.dart';
import '../models/contact_profile.dart';
import '../di/service_locator.dart';
import '../services/user_id_service.dart';
import '../services/p2p/map_object_storage.dart';

/// Экран редактирования профиля для контактов
class ProfileScreen extends StatefulWidget {
  final String? userId; // Если null - редактируем свой профиль

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final UserIdService _userIdService = getIt<UserIdService>();
  late final MapObjectStorage _storage = getIt<MapObjectStorage>();
  
  late Future<_ProfileData> _profileFuture;
  
  // Контроллеры
  final _aboutController = TextEditingController();
  final _vkController = TextEditingController();
  final _maxController = TextEditingController();
  
  // Состояние
  ContactVisibility _visibility = ContactVisibility.afterApproval;
  bool _acceptP2PMessages = true;
  bool _isLoading = false;
  bool _hasChanges = false;
  
  // Данные пользователя
  String? _currentUserId;
  String _userName = 'Прогульщик';
  int _userReputation = 0;
  
  bool get _isEditMode => widget.userId == null;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }
  
  @override
  void dispose() {
    _aboutController.dispose();
    _vkController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<_ProfileData> _loadProfile() async {
    // Получаем информацию о текущем пользователе
    final userInfo = await _userIdService.getUserInfo();
    _currentUserId = userInfo.id;
    _userName = userInfo.name;
    _userReputation = userInfo.reputation;
    
    // Определяем чей профиль загружаем
    final targetUserId = widget.userId ?? _currentUserId!;
    
    // Загружаем профиль
    final profileJson = await _storage.getContactProfile(targetUserId);
    
    ContactProfile? profile;
    if (profileJson != null) {
      // Конвертируем ключи из snake_case в camelCase
      final converted = <String, dynamic>{};
      profileJson.forEach((key, value) {
        switch (key) {
          case 'user_id':
            converted['userId'] = value;
            break;
          case 'about':
            converted['about'] = value;
            break;
          case 'vk_link':
            converted['vkLink'] = value;
            break;
          case 'max_link':
            converted['maxLink'] = value;
            break;
          case 'visibility':
            converted['visibility'] = value;
            break;
          case 'accept_p2p_messages':
            converted['acceptP2PMessages'] = value == 1 || value == true;
            break;
          default:
            converted[key] = value;
        }
      });
      profile = ContactProfile.fromJson(converted);
    }
    
    return _ProfileData(
      userId: targetUserId,
      userName: widget.userId == null ? _userName : 'Пользователь',
      reputation: _userReputation,
      profile: profile,
    );
  }

  void _initControllers(ContactProfile? profile) {
    _aboutController.text = profile?.about ?? '';
    _vkController.text = profile?.vkLink ?? '';
    _maxController.text = profile?.maxLink ?? '';
    _visibility = profile?.visibility ?? ContactVisibility.afterApproval;
    _acceptP2PMessages = profile?.acceptP2PMessages ?? true;
    
    // Слушатели для отслеживания изменений
    _aboutController.addListener(_markChanged);
    _vkController.addListener(_markChanged);
    _maxController.addListener(_markChanged);
  }
  
  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveProfile() async {
    if (!_isEditMode) return;
    
    setState(() => _isLoading = true);
    
    try {
      final profile = ContactProfile(
        userId: _currentUserId!,
        about: _aboutController.text.trim(),
        vkLink: _vkController.text.trim().isNotEmpty 
            ? _vkController.text.trim() 
            : null,
        maxLink: _maxController.text.trim().isNotEmpty 
            ? _maxController.text.trim() 
            : null,
        visibility: _visibility,
        acceptP2PMessages: _acceptP2PMessages,
      );
      
      await _storage.saveContactProfile(profile.toJson());
      
      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Профиль сохранён'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Мой профиль' : 'Профиль контакта'),
        actions: [
          if (_isEditMode && _hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Сохранить'),
            ),
        ],
      ),
      body: FutureBuilder<_ProfileData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Ошибка: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _profileFuture = _loadProfile()),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          
          final data = snapshot.data!;
          
          // Инициализируем контроллеры один раз
          if (_aboutController.text.isEmpty) {
            _initControllers(data.profile);
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Карточка пользователя
                _buildUserCard(data),
                const SizedBox(height: 24),
                
                // Секция "О себе"
                if (_isEditMode) ...[
                  _buildSectionHeader('О себе'),
                  TextField(
                    controller: _aboutController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      hintText: 'Расскажите немного о себе...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Секция "Контакты"
                  _buildSectionHeader('Контакты для связи'),
                  _buildInfoCard(
                    'Другие пользователи смогут связаться с вами через эти мессенджеры, '
                    'если вы разрешите показ контакта.',
                  ),
                  const SizedBox(height: 12),
                  
                  // VK
                  TextField(
                    controller: _vkController,
                    decoration: const InputDecoration(
                      labelText: 'ВКонтакте',
                      hintText: 'https://vk.com/username',
                      prefixIcon: Icon(Icons.language),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  
                  // Max
                  TextField(
                    controller: _maxController,
                    decoration: const InputDecoration(
                      labelText: 'Max Messenger',
                      hintText: 'https://max.ru/u/...',
                      prefixIcon: Icon(Icons.chat),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 24),
                  
                  // Секция "Видимость"
                  _buildSectionHeader('Видимость контакта'),
                  _buildInfoCard(
                    'Контролируйте, кто может видеть ваши контактные данные. '
                    '"Интересно" — пользователи, отметившие ваши заметки.',
                  ),
                  const SizedBox(height: 12),
                  
                  // Выбор видимости
                  ...ContactVisibility.values.map((v) => _buildVisibilityOption(v)),
                  const SizedBox(height: 24),
                  
                  // P2P сообщения
                  _buildSectionHeader('P2P Сообщения'),
                  Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.message),
                      title: const Text('Принимать сообщения'),
                      subtitle: const Text(
                        'Другие пользователи смогут писать вам напрямую через приложение',
                      ),
                      value: _acceptP2PMessages,
                      onChanged: (value) {
                        setState(() {
                          _acceptP2PMessages = value;
                          _hasChanges = true;
                        });
                      },
                    ),
                  ),
                ] else ...[
                  // Режим просмотра чужого профиля
                  _buildViewMode(data),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildUserCard(_ProfileData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                data.userName.isNotEmpty ? data.userName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Репутация: ${data.reputation}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${data.userId.substring(0, 8).toUpperCase()}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVisibilityOption(ContactVisibility v) {
    final isSelected = _visibility == v;
    String description;
    IconData icon;
    
    switch (v) {
      case ContactVisibility.afterApproval:
        description = 'Только после вашего одобрения';
        icon = Icons.check_circle_outline;
        break;
      case ContactVisibility.afterInterest:
        description = 'Пользователи, отметившие "Интересно"';
        icon = Icons.favorite_outline;
        break;
      case ContactVisibility.nobody:
        description = 'Скрыть от всех';
        icon = Icons.lock_outline;
        break;
    }
    
    return InkWell(
      onTap: () {
        setState(() {
          _visibility = v;
          _hasChanges = true;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildViewMode(_ProfileData data) {
    final profile = data.profile;
    
    if (profile == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Профиль не заполнен',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // О себе
        if (profile.about.isNotEmpty) ...[
          _buildSectionHeader('О себе'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(profile.about),
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Контакты (если доступны)
        if (profile.hasExternalMessengers) ...[
          _buildSectionHeader('Контакты'),
          if (profile.vkLink != null)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.language, color: Colors.white),
              ),
              title: const Text('ВКонтакте'),
              subtitle: Text(profile.vkLink!),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // Открыть ссылку
              },
            ),
          if (profile.maxLink != null)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat, color: Colors.white),
              ),
              title: const Text('Max Messenger'),
              subtitle: Text(profile.maxLink!),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // Открыть ссылку
              },
            ),
          const SizedBox(height: 24),
        ],
        
        // P2P сообщения
        if (profile.acceptP2PMessages) ...[
          _buildSectionHeader('Сообщение'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.message, size: 48, color: Colors.green),
                  const SizedBox(height: 8),
                  const Text('Можно отправить сообщение'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Открыть чат
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('P2P чат в разработке')),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Написать'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProfileData {
  final String userId;
  final String userName;
  final int reputation;
  final ContactProfile? profile;
  
  _ProfileData({
    required this.userId,
    required this.userName,
    required this.reputation,
    this.profile,
  });
}
