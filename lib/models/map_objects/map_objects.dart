/// Map Objects System
/// Расширяемая система объектов на карте

import 'map_object.dart';
import 'trash_monster.dart';
import 'secret_message.dart';
import 'creature.dart';

/// Инициализация фабрики для создания объектов по типу
void _initObjectFactory() {
  MapObject.setObjectFactory((json) {
    final type = MapObjectType.fromCode(json['type'] as String);
    
    switch (type) {
      case MapObjectType.trashMonster:
        return TrashMonster.fromSyncJson(json);
      case MapObjectType.secretMessage:
        return SecretMessage.fromSyncJson(json);
      case MapObjectType.creature:
        return Creature.fromSyncJson(json);
      default:
        return MapObject._fromJson(json);
    }
  });
}

// Автоматическая инициализация при импорте
final _ = _initObjectFactory();

export 'map_object.dart';
export 'trash_monster.dart';
export 'secret_message.dart';
export 'creature.dart';
