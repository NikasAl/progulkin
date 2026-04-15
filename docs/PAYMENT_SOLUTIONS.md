# Способы приёма донатов в мобильном приложении (Россия)

## Введение

Документ описывает возможные способы интеграции платежей в мобильное приложение "Прогулкин" без использования собственного сервера, с учётом ограничений платёжных систем в России и требованием верификации прохождения платежа.

---

## Ключевые ограничения в России

| Ограничение | Описание |
|-------------|----------|
| **Нет Stripe/PayPal** | Международные платёжные системы не работают с российскими пользователями |
| **Нужна фискализация** | По закону 54-ФЗ все платежи должны пробиваться через онлайн-кассу |
| **Требуется ИП/самозанятость** | Для приёма платежей нужен юридический статус |
| **Санкции** | Некоторые сервисы ограничили работу с российскими банками |

---

## Варианты решения

### 1. YooKassa (ЮKassa) — Рекомендуемый вариант

**Статус:** ✅ Работает в России, есть Flutter SDK

**Как это работает:**
```
Приложение → YooKassa SDK → Токен платежа → API ЮKassa → Webhook на серверeless функцию
```

**Плюсы:**
- Официальный Flutter SDK: `yookassa_payments_flutter`
- Поддержка СБП, банковских карт, SberPay, T-Pay, ЮMoney
- Фискализация включена в сервис (54-ФЗ)
- Мощное API с вебхуками
- Работает для ИП и самозанятых

**Минусы:**
- Требует ИП или статус самозанятого
- Комиссия 2.8–3.5%
- Для верификации платежа нужен webhook-обработчик

**Архитектура без собственного сервера:**
```
┌─────────────┐     ┌─────────────────┐     ┌──────────────────┐
│   Flutter   │────▶│   YooKassa API  │────▶│ Firebase/Supabase│
│     App     │     │    (платёж)     │     │  Cloud Function  │
└─────────────┘     └─────────────────┘     └──────────────────┘
                                                   │
                                                   ▼
                                            ┌──────────────────┐
                                            │ Валидация вебхука│
                                            │ Запись в БД      │
                                            └──────────────────┘
```

**Пример кода (Flutter):**
```dart
import 'package:yookassa_payments_flutter/yookassa_payments_flutter.dart';

// Создание платежа (через API — нужен backend или Cloud Function)
final payment = await YooKassaPaymentsFlutter.tokenization(
  TokenizationModuleInputData(
    clientApplicationKey: 'your_client_key', // Публичный ключ
    shopName: 'Прогулкин',
    purchase: Purchase(
      amount: Amount(value: 100, currency: Currency.rub),
      description: 'Покупка предметов для существ',
    ),
  ),
);

if (payment.status == TokenizationResultStatus.success) {
  // Отправить токен на backend/cloud function для подтверждения
  await confirmPayment(payment.token);
}
```

**Вебхук через Firebase Cloud Functions:**
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.yookassaWebhook = functions.https.onRequest(async (req, res) => {
  const event = req.body;

  // Проверка подписи webhook (важно для безопасности!)
  if (event.type === 'notification' && event.event === 'payment.succeeded') {
    const payment = event.object;

    // Записываем успешный платёж в Firestore
    await admin.firestore().collection('payments').doc(payment.id).set({
      userId: payment.metadata.user_id,
      amount: payment.amount.value,
      status: 'succeeded',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Начисляем предметы пользователю
    await grantItemsToUser(payment.metadata.user_id, payment.metadata.items);
  }

  res.status(200).send('OK');
});
```

**Ссылки:**
- [YooKassa Flutter SDK](https://pub.dev/packages/yookassa_payments_flutter)
- [Документация YooKassa](https://yookassa.ru/developers)
- [Мобильные SDK](https://yookassa.ru/integration-mobile)

---

### 2. СБП через QR-код

**Статус:** ✅ Работает в России, низкая комиссия

**Как это работает:**
```
Приложение → Генерация QR → Пользователь сканирует в приложении банка → Polling статуса
```

**Плюсы:**
- Комиссия 0.4–0.7% (минимальная на рынке)
- Работает со всеми российскими банками
- Не нужен QR-сканер в приложении
- Мгновенные переводы 24/7

**Минусы:**
- Требуется договор с банком-эквайером (Тинькофф, Сбер, Райффайзен и др.)
- Для статуса нужен polling или webhook
- Нет готового Flutter SDK — нужно интегрировать через API

**Архитектура без сервера:**
```
┌─────────────┐     ┌───────────────┐     ┌──────────────────┐
│   Flutter   │────▶│  СБП API      │────▶│ Polling статуса  │
│     App     │     │ (через банк)  │     │ каждые 3 сек     │
└─────────────┘     └───────────────┘     └──────────────────┘
```

**Пример (через Tinkoff Acquiring):**
```dart
import 'package:tinkoff_acquiring/tinkoff_acquiring.dart';

// Создание QR-кода для оплаты
final qrResponse = await tinkoffClient.initQr({
  'Amount': 10000, // 100 рублей в копейках
  'OrderId': 'order_123',
  'Description': 'Донат в Прогулкине',
});

// Отображаем QR-код пользователю
showQrCode(qrResponse.qrCode);

// Polling статуса платежа
Timer.periodic(Duration(seconds: 3), (timer) async {
  final status = await tinkoffClient.getState({'PaymentId': qrResponse.paymentId});
  if (status.status == 'CONFIRMED') {
    timer.cancel();
    onPaymentSuccess();
  }
});
```

**Ссылки:**
- [Tinkoff Acquiring Flutter SDK](https://pub.dev/packages/tinkoff_acquiring)
- [СБП для бизнеса](https://sbp.nspk.ru/business)
- [Документация СБП API](https://sbp.nspk.ru/api/new)

---

### 3. Telegram Stars — Для Mini App

**Статус:** ✅ Идеально для Telegram Mini App

**Как это работает:**
```
Mini App → Telegram Stars API → Вывод на карту через Fragment
```

**Плюсы:**
- Не нужен ИП! Работает для физлиц
- Нет комиссий за приём платежей
- Встроено в Telegram
- Простая интеграция через Bot API

**Минусы:**
- Работает только внутри Telegram
- Комиссия при выводе ~10-15%
- Только цифровые товары/услуги
- Ограниченная аудитория (пользователи Telegram)

**Архитектура:**
```
┌───────────────┐     ┌──────────────┐     ┌─────────────────┐
│ Telegram Mini │────▶│ Telegram Bot │────▶│  Fragment.io    │
│     App       │     │    API       │     │   (вывод)       │
└───────────────┘     └──────────────┘     └─────────────────┘
```

**Пример кода:**
```dart
// Отправка инвойса через Bot API
final invoice = await telegram.sendInvoice(
  chatId: userId,
  title: 'Мешочек орехов для белочки',
  description: 'Приручить белочку вкусными орешками',
  payload: 'item_nuts_100',
  currency: 'XTR', // Telegram Stars
  prices: [
    LabeledPrice(label: 'Орехи', amount: 100), // 100 Stars
  ],
);

// Обработка успешного платежа
bot.onSuccessfulPayment((payment) {
  final userId = payment.from.id;
  final payload = payment.successful_payment.invoice_payload;

  // Начисляем предмет
  grantItemToUser(userId, payload);
});
```

**Ссылки:**
- [Telegram Stars API](https://core.telegram.org/bots/payments-stars)
- [Bot Payments API](https://core.telegram.org/bots/payments)

---

### 4. Telegram Bot @donate

**Статус:** ✅ Простой донат для контент-криэйторов

**Как это работает:**
```
Пользователь → Бот @donate → Перевод на карту/кошелёк
```

**Плюсы:**
- Не нужен ИП для небольших сумм
- Простая настройка
- Поддержка карт РФ, СБП
- Встроено в Telegram

**Минусы:**
- Нет официального API для проверки платежей
- Ограниченные возможности интеграции
- Комиссия сервиса
- Нельзя полностью автоматизировать

**Возможное решение:**
Использовать как альтернативный канал донатов с ручной обработкой или через сторонние сервисы мониторинга.

**Ссылки:**
- [Бот @donate](https://t.me/donate)

---

### 5. Prodamus

**Статус:** ✅ Работает в России, включает фискализацию

**Как это работает:**
```
Приложение → Платёжная страница Prodamus → Webhook → Serverless
```

**Плюсы:**
- Полная фискализация включена
- Работает для ИП, ООО и самозанятых
- СБП, карты, СберPay, T-Pay
- Интеграция с «Мой налог» для самозанятых
- Нет абонентской платы

**Минусы:**
- Комиссия 3.5–4%
- Нет готового Flutter SDK
- Требуется webhook-обработчик

**Архитектура:**
```
┌─────────────┐     ┌───────────────────┐     ┌──────────────────┐
│   Flutter   │────▶│  Платёжная ссылка │────▶│   Webhook на     │
│     App     │     │    Prodamus       │     │ Cloud Function   │
└─────────────┘     └───────────────────┘     └──────────────────┘
```

**Пример:**
```dart
// Открытие платёжной страницы в WebView
final paymentUrl = 'https://pay.prodamus.ru/your_form?amount=100&item=donuts';

await launchUrl(
  Uri.parse(paymentUrl),
  mode: LaunchMode.inAppWebView,
);

// Webhook на Cloud Function
exports.prodamusWebhook = functions.https.onRequest(async (req, res) => {
  // Проверка подписи
  const sign = req.headers['sign'];
  if (!verifySign(req.body, sign)) {
    return res.status(400).send('Invalid signature');
  }

  // Обработка успешного платежа
  if (req.body.status === 'success') {
    await grantItemsToUser(req.body.custom.user_id, req.body.custom.items);
  }

  res.status(200).send('OK');
});
```

**Ссылки:**
- [Prodamus](https://prodamus.ru)
- [Документация API](https://help.prodamus.ru/payform/integracii/rest-api)

---

### 6. CloudPayments

**Статус:** ✅ Работает в России

**Плюсы:**
- Flutter SDK: `cloudpayments`
- СБП, T-Pay, Mir Pay
- Рекуррентные платежи
- Виджет для сайта

**Минусы:**
- Требуется ИП
- Комиссия ~3%
- Ограниченная документация по Flutter SDK

**Ссылки:**
- [CloudPayments Flutter](https://pub.dev/packages/cloudpayments)
- [Документация](https://developers.cloudpayments.ru)

---

### 7. DonationAlerts / Donate.stream — Для стримеров

**Статус:** ⚠️ Ограниченная интеграция

**Плюсы:**
- Популярные платформы для донатов
- API для уведомлений о донатах

**Минусы:**
- Заточены под стриминговые платформы
- Нет мобильного SDK
- Комиссия платформы

**Возможное использование:**
Как дополнительный канал донатов с уведомлениями через WebSocket API.

---

## Сравнение решений

| Решение | Без ИП | Flutter SDK | СБП | Webhook | Комиссия | Сложность |
|---------|--------|-------------|-----|---------|----------|-----------|
| **YooKassa** | ❌ | ✅ | ✅ | ✅ | 2.8-3.5% | Средняя |
| **СБП (через банк)** | ❌ | ⚠️ | ✅ | ✅ | 0.4-0.7% | Высокая |
| **Telegram Stars** | ✅ | N/A | ❌ | ✅ | 10-15% (вывод) | Низкая |
| **Telegram @donate** | ✅ | ❌ | ✅ | ⚠️ | Переменная | Низкая |
| **Prodamus** | ❌ | ❌ | ✅ | ✅ | 3.5-4% | Средняя |
| **CloudPayments** | ❌ | ✅ | ✅ | ✅ | ~3% | Средняя |

---

## Рекомендуемая архитектура для "Прогулкина"

### Вариант A: Telegram Mini App (рекомендуется)

Если приложение интегрировано в Telegram как Mini App:

```
┌─────────────────────────────────────────────────────────────┐
│                    Telegram Mini App                        │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ Flutter App  │───▶│ Telegram Bot │───▶│ Telegram     │  │
│  │              │    │ API          │    │ Stars        │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                                        │          │
│         ▼                                        ▼          │
│  ┌──────────────┐                        ┌──────────────┐  │
│  │ Supabase DB  │◀─────── Webhook ───────│ Cloud        │  │
│  │ (покупки)    │                        │ Function     │  │
│  └──────────────┘                        └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**Преимущества:**
- Не нужен ИП для старта
- Минимальные затраты на инфраструктуру
- Нативная интеграция с Telegram

### Вариант B: Автономное приложение

Для standalone Flutter-приложения:

```
┌─────────────────────────────────────────────────────────────┐
│                  Автономное приложение                      │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ Flutter App  │───▶│ YooKassa SDK │───▶│ YooKassa     │  │
│  │              │    │              │    │ API          │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                                        │          │
│         ▼                                        ▼          │
│  ┌──────────────┐                        ┌──────────────┐  │
│  │ Firebase     │◀─────── Webhook ───────│ Firebase     │  │
│  │ Firestore    │                        │ Cloud Func   │  │
│  └──────────────┘                        └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**Преимущества:**
- Полный контроль над UX
- Профессиональное решение
- YooKassa — проверенная платформа

---

## Serverless-решения для вебхуков

### Firebase Cloud Functions (Рекомендуется)

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.yookassaWebhook = functions.https.onRequest(async (req, res) => {
  // Проверка IP вебхука (безопасность)
  const allowedIPs = ['185.71.76.0/27', '185.71.77.0/27'];
  // ... проверка IP ...

  const event = req.body;

  if (event.type === 'notification' && event.event === 'payment.succeeded') {
    const payment = event.object;

    // Атомарная запись в Firestore
    await admin.firestore().runTransaction(async (transaction) => {
      const userRef = admin.firestore().collection('users').doc(payment.metadata.user_id);

      transaction.set(userRef.collection('purchases').doc(payment.id), {
        amount: payment.amount.value,
        items: payment.metadata.items,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(userRef, {
        totalSpent: admin.firestore.FieldValue.increment(payment.amount.value),
      });
    });
  }

  res.status(200).send('OK');
});
```

### Supabase Edge Functions

```typescript
// supabase/functions/yookassa-webhook/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  const event = await req.json();

  if (event.type === 'notification' && event.event === 'payment.succeeded') {
    const payment = event.object;
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    await supabase.from('purchases').insert({
      user_id: payment.metadata.user_id,
      amount: payment.amount.value,
      items: payment.metadata.items,
      status: 'completed',
    });
  }

  return new Response('OK', { status: 200 });
});
```

---

## Безопасность

### Критически важные меры:

1. **Проверка подписи вебхуков** — Всегда проверяйте HMAC-подпись от платёжной системы
2. **IP-ограничения** — Принимайте вебхуки только с IP платёжной системы
3. **Идемпотентность** — Обрабатывайте каждый платёж только один раз
4. **HTTPS обязательно** — Все запросы должны быть зашифрованы

### Пример проверки подписи YooKassa:

```javascript
const crypto = require('crypto');

function verifyWebhookSignature(body, signature, secret) {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(body))
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}
```

---

## Итоговые рекомендации

### Для MVP (без ИП):
1. **Telegram Stars** — если приложение как Telegram Mini App
2. **Telegram @donate** — как дополнительный канал

### Для продакшена (с ИП/самозанятостью):
1. **YooKassa** — лучшее соотношение цена/качество
2. **СБП** — минимальная комиссия, если готовы к сложной интеграции

### Инфраструктура:
- **Firebase Cloud Functions** — для вебхуков (бесплатно до 125K запросов/день)
- **Supabase** — альтернатива с PostgreSQL

---

## Ссылки

- [YooKassa Flutter SDK](https://pub.dev/packages/yookassa_payments_flutter)
- [Tinkoff Acquiring Flutter](https://pub.dev/packages/tinkoff_acquiring)
- [Telegram Stars Payments](https://core.telegram.org/bots/payments-stars)
- [СБП для бизнеса](https://sbp.nspk.ru/business)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Prodamus](https://prodamus.ru)
- [CloudPayments](https://cloudpayments.ru)
