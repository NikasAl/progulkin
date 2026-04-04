/// Map Objects System
/// Расширяемая система объектов на карте
library;

export 'map_object.dart';
export 'trash_monster.dart';
export 'secret_message.dart';
export 'creature.dart';
export 'interest_note.dart';
export 'reminder_character.dart';
export 'foraging_spot.dart';

import 'map_object.dart';
import 'trash_monster.dart';
import 'secret_message.dart';
import 'creature.dart';
import 'interest_note.dart';
import 'reminder_character.dart';
import 'foraging_spot.dart';

/// Инициализация фабрики для создания объектов по типу
/// ВЫЗЫВАТЬ В main.dart ДО ИСПОЛЬЗОВАНИЯ ЛЮБОГО MapObject.fromSyncJson()
void initMapObjectFactory() {
  MapObject.setObjectFactory((json) {
    final type = MapObjectType.fromCode(json['type'] as String);
    
    switch (type) {
      case MapObjectType.trashMonster:
        return TrashMonster.fromSyncJson(json);
      case MapObjectType.secretMessage:
        return SecretMessage.fromSyncJson(json);
      case MapObjectType.creature:
        return Creature.fromSyncJson(json);
      case MapObjectType.interestNote:
        return InterestNote.fromSyncJson(json);
      case MapObjectType.reminderCharacter:
        return ReminderCharacter.fromSyncJson(json);
      case MapObjectType.foragingSpot:
        return ForagingSpot.fromSyncJson(json);
      default:
        return MapObject.fromJson(json);
    }
  });
}

// Автоматическая инициализация при импорте (резервный вариант)
// Выполняется при первом импорте этого файла
void _autoInit() {
  initMapObjectFactory();
}

// Игнорируем предупреждение о неиспользуемой переменной
// ignore: unused_element
final _autoInitResult = (_autoInit());
