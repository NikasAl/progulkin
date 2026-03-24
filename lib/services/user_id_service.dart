import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Сервис для управления уникальным идентификатором пользователя/устройства
class UserIdService {
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userReputationKey = 'user_reputation';
  
  String? _userId;
  String? _userName;
  int _reputation = 0;
  
  /// Получить ID пользователя (создаётся при первом запуске)
  Future<String> getUserId() async {
    if (_userId != null) return _userId!;
    
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_userIdKey);
    
    if (_userId == null) {
      _userId = const Uuid().v4();
      await prefs.setString(_userIdKey, _userId!);
    }
    
    return _userId!;
  }
  
  /// Получить имя пользователя
  Future<String> getUserName() async {
    if (_userName != null) return _userName!;
    
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString(_userNameKey) ?? 'Прогульщик';
    
    return _userName!;
  }
  
  /// Установить имя пользователя
  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
    _userName = name;
  }
  
  /// Получить репутацию пользователя
  Future<int> getReputation() async {
    if (_reputation > 0) return _reputation;
    
    final prefs = await SharedPreferences.getInstance();
    _reputation = prefs.getInt(_userReputationKey) ?? 0;
    
    return _reputation;
  }
  
  /// Добавить очки репутации
  Future<void> addReputation(int points) async {
    final prefs = await SharedPreferences.getInstance();
    _reputation = await getReputation() + points;
    await prefs.setInt(_userReputationKey, _reputation);
  }
  
  /// Получить всю информацию о пользователе
  Future<UserInfo> getUserInfo() async {
    return UserInfo(
      id: await getUserId(),
      name: await getUserName(),
      reputation: await getReputation(),
    );
  }
}

/// Информация о пользователе
class UserInfo {
  final String id;
  final String name;
  final int reputation;
  
  const UserInfo({
    required this.id,
    required this.name,
    required this.reputation,
  });
}
