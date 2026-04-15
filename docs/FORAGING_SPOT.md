# Грибы и ягоды (ForagingSpot)

## Обзор

Тип объекта `ForagingSpot` позволяет отмечать места для сбора лесных даров — грибов, ягод, орехов и трав. Полезно для любителей лесных прогулок, которые хотят делиться находками с другими пользователями.

## Модель данных

### ForagingSpot

```dart
class ForagingSpot extends MapObject {
  final ForagingCategory category;      // Категория (грибы/ягоды/орехи/травы)
  final String itemTypeCode;            // Код конкретного типа
  final ForagingQuantity quantity;      // Количество
  final ForagingSeason season;          // Сезон
  final String notes;                   // Заметки пользователя
  final bool isVerified;                // Подтверждено другими
  final int harvestCount;               // Сколько раз собирали
  final DateTime? lastHarvest;          // Последний сбор
  final double accessibility;           // Доступность (0-1)
}
```

## Категории

### 🍄 Грибы (MushroomType)

| Код | Название | Съедобный |
|-----|----------|-----------|
| white | Белый гриб | ✅ |
| boletus | Подберёзовик | ✅ |
| orange_cap | Подосиновик | ✅ |
| chanterelle | Лисичка | ✅ |
| honey_fungus | Опёнок | ✅ |
| russula | Сыроежка | ✅ |
| milk_mushroom | Груздь | ✅ |
| saffron_milk_cap | Рыжик | ✅ |
| morel | Сморчок | ✅ |
| oyster | Вешенка | ✅ |
| champignon | Шампиньон | ✅ |
| porcini | Боровик | ✅ |
| other_mushroom | Другой гриб | ❓ |

### 🫐 Ягоды (BerryType)

| Код | Название | Съедобный |
|-----|----------|-----------|
| blueberry | Черника | ✅ |
| lingonberry | Брусника | ✅ |
| cranberry | Клюква | ✅ |
| cloudberry | Морошка | ✅ |
| strawberry | Земляника | ✅ |
| raspberry | Малина | ✅ |
| currant | Смородина | ✅ |
| gooseberry | Крыжовник | ✅ |
| rowan | Рябина | ✅ |
| rosehip | Шиповник | ✅ |
| hawthorn | Боярышник | ✅ |
| juniper | Можжевельник | ✅ |
| other_berry | Другая ягода | ❓ |

### 🥜 Орехи (NutType)

| Код | Название | Съедобный |
|-----|----------|-----------|
| hazelnut | Лещина (фундук) | ✅ |
| pine_nut | Кедровый орех | ✅ |
| walnut | Грецкий орех | ✅ |
| acorn | Жёлудь | ❌ |
| other_nut | Другой орех | ❓ |

### 🌿 Травы (HerbType)

| Код | Название | Съедобный |
|-----|----------|-----------|
| nettle | Крапива | ✅ |
| dandelion | Одуванчик | ✅ |
| sorrel | Щавель | ✅ |
| wild_garlic | Черемша | ✅ |
| mint | Мята | ✅ |
| chamomile | Ромашка | ✅ |
| st_johns_wort | Зверобой | ✅ |
| thyme | Чабрец | ✅ |
| yarrow | Тысячелистник | ✅ |
| plantain | Подорожник | ✅ |
| other_herb | Другая трава | ❓ |

## Количество (ForagingQuantity)

| Код | Название | Диапазон | Уровень |
|-----|----------|----------|---------|
| few | Немного | 1-5 | 1 |
| some | Средне | 5-20 | 2 |
| many | Много | 20-50 | 3 |
| abundant | Очень много | 50+ | 4 |

## Сезонность (ForagingSeason)

| Код | Название | Месяцы |
|-----|----------|--------|
| spring | Весна | 3, 4, 5 |
| summer | Лето | 6, 7, 8 |
| autumn | Осень | 9, 10, 11 |
| winter | Зима | 12, 1, 2 |
| all_year | Круглый год | все |

## API провайдера

### Создание места сбора

```dart
final spot = await mapObjectProvider.createForagingSpot(
  latitude: 55.7558,
  longitude: 37.6173,
  ownerId: userId,
  ownerName: 'Имя',
  category: ForagingCategory.mushroom,
  itemTypeCode: 'white',
  quantity: ForagingQuantity.many,
  season: ForagingSeason.autumn,
  notes: 'Растут под ёлками',
);
```

### Отметить сбор

```dart
await mapObjectProvider.markForagingHarvest(spotId);
```

### Подтвердить место

```dart
await mapObjectProvider.verifyForagingSpot(spotId);
```

### Получить места сбора

```dart
// Рядом с пользователем
final nearby = mapObjectProvider.getForagingSpotsNearby();

// По категории
final mushrooms = mapObjectProvider.getForagingSpotsByCategory(ForagingCategory.mushroom);

// В сезон
final inSeason = mapObjectProvider.getForagingSpotsInSeason();
```

## UI

### Экран создания

Форма включает:
1. **Категория** — выбор из 4 категорий (грибы/ягоды/орехи/травы)
2. **Вид** — динамически обновляется в зависимости от категории
3. **Количество** — мало/средне/много/очень много
4. **Сезон** — весна/лето/осень/зима/круглый год
5. **Заметки** — текстовое поле для заметок

### Предупреждение о безопасности

При создании места сбора отображается предупреждение:
> "Собирайте только те грибы и ягоды, в которых уверены. Некоторые виды могут быть опасны!"

## Синхронизация

ForagingSpot полностью поддерживает P2P синхронизацию:

- `toSyncJson()` — экспорт для синхронизации
- `fromSyncJson()` — импорт при получении от другого устройства

## Будущие улучшения

- [ ] Фильтрация по сезону на карте
- [ ] Фильтрация по категории
- [ ] Фото мест сбора
- [ ] История сборов
- [ ] Индикатор "горячих" мест (много подтверждений)
