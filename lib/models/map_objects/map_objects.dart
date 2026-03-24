/// Map Objects System
/// Расширяемая система объектов на карте

export 'map_object.dart';
export 'trash_monster.dart';
export 'secret_message.dart';
export 'creature.dart';

import 'map_object.dart';
import 'trash_monster.dart';
import 'secret_message.dart';
import 'creature.dart';

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
