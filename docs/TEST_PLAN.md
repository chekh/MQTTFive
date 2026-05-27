# MQTTFive — План тестирования

## Подход

Каждый тест использует **два MQTTClient** в одном скрипте:
- **Client A** (subscriber) — подключается, подписывается, ждёт сообщения
- **Client B** (publisher) — подключается, публикует, отключается

Оба клиента подключаются к одному брокеру. Это даёт полный roundtrip без внешних инструментов.

## Скрипты

| # | Скрипт | Что тестирует | Время |
|---|--------|---------------|-------|
| T01 | `TestT01_Connect.mq5` | Connect/Disconnect lifecycle, CONNACK properties | 5 сек |
| T02 | `TestT02_Qos0Roundtrip.mq5` | QoS 0 pub/sub roundtrip, callback verification | 5 сек |
| T03 | `TestT03_Qos1Roundtrip.mq5` | QoS 1 pub/sub, PUBACK flow, inflight clear | 5 сек |
| T04 | `TestT04_Qos2Roundtrip.mq5` | QoS 2 pub/sub, PUBREC/PUBREL/PUBCOMP full flow | 10 сек |
| T05 | `TestT05_Properties.mq5` | CONNECT props, CONNACK props parsed, Session Expiry | 5 сек |
| T06 | `TestT06_WillMessage.mq5` | Will message delivered after abnormal disconnect | 10 сек |
| T07 | `TestT07_Keepalive.mq5` | PINGREQ sent after keep_alive, PINGRESP received | 25 сек |
| T08 | `TestT08_FlowControl.mq5` | Receive Maximum enforcement, quota restore on PUBACK | 10 сек |
| T09 | `TestT09_TopicAlias.mq5` | Alias register + reuse, empty topic on second publish | 5 сек |
| T10 | `TestT10_SubscriptionOptions.mq5` | No Local, Retain As Published, Retain Handling | 10 сек |
| T11 | `TestT11_Unsubscribe.mq5` | SUBSCRIBE → receive → UNSUBSCRIBE → no more messages | 10 сек |
| T12 | `TestT12_LargePayload.mq5` | 1KB, 10KB, 50KB payloads, binary-safe | 10 сек |
| T13 | `TestT13_Utf8Topics.mq5` | Русские топики, спецсимволы в payload | 5 сек |
| T14 | `TestT14_BinaryPayload.mq5` | 0x00-0xFF byte range, no corruption | 5 сек |
| T15 | `TestT15_MultiPubSub.mq5` | 3 subscribers, 1 publisher, all receive | 10 сек |

## Требования к окружению

- Mosquitto >= 5.0 (или другой MQTT 5.0 брокер) запущен на `InpHost:InpPort`
- Брокер не требует авторизации (или указаны InpUsername/InpPassword)
- Брокер поддерживает Topic Alias (для T09)
- Нет других клиентов на тех же client_id

## Как читать результаты

Каждый тест выводит:
```
=== Test T0N: <Name> ===
PASS: <assertion description>
FAIL: <assertion description>
=== T0N: N passed, M failed ===
```

Если все PASS — тест пройден. Если есть FAIL — в логе будет контекст.

## Порядок запуска

1. T01 (connect) — базовый, проверить что брокер доступен
2. T02 (QoS 0) — базовый roundtrip
3. T03 (QoS 1) — PUBACK
4. T04 (QoS 2) — полный QoS 2 flow
5. T05-T15 — остальные в любом порядке

## Детальные сценарии

### T01: Connect/Disconnect
1. Client A подключается с `client_id = "t01_a"`
2. Проверить: `IsConnected() == true`
3. Проверить: CONNACK `reason_code == 0x00`
4. Проверить: CONNACK `has_receive_maximum == true`, `receive_maximum > 0`
5. Отключиться
6. Проверить: `IsConnected() == false`

### T02: QoS 0 Roundtrip
1. Client A: subscribe `test/t02`, QoS 0
2. Client B: publish `test/t02`, payload "hello qos0", QoS 0
3. Client A: Loop() до получения сообщения
4. Проверить: callback получил topic == "test/t02"
5. Проверить: payload == "hello qos0"
6. Проверить: payload_len == 10

### T03: QoS 1 Roundtrip
1. Client A: subscribe `test/t03`, QoS 1
2. Client B: publish `test/t03`, payload "qos1-test", QoS 1
3. Client A: Loop() до получения
4. Проверить: payload == "qos1-test"
5. Client B: Loop() — получить PUBACK
6. Проверить: PUBACK получен (inflight очищен)

### T04: QoS 2 Roundtrip
1. Client A: subscribe `test/t04`, QoS 2
2. Client B: publish `test/t04`, payload "exactly-once", QoS 2
3. Client A: Loop() — получить PUBLISH QoS 2 → отправить PUBREC
4. Client B: Loop() — получить PUBREC → отправить PUBREL
5. Client A: Loop() — получить PUBREL → отправить PUBCOMP → callback
6. Client B: Loop() — получить PUBCOMP → inflight очищен
7. Проверить: Client A callback получил payload == "exactly-once"
8. Проверить: Client B inflight пуст (send_quota restored)

### T05: Properties
1. Client: connect с `session_expiry_interval=300`, `receive_maximum=5`
2. Проверить: CONNACK parsed — `has_session_expiry` or `has_receive_maximum`
3. Проверить: `receive_maximum == 20` (или что брокер вернул)
4. Проверить: `maximum_qos == 2` (Mosquitto default)
5. Проверить: `retain_available == true`
6. Disconnect с `reason_code=0x00`, `session_expiry=300`

### T06: Will Message
1. Client A: subscribe `test/t06/will`, QoS 0
2. Client B: connect с `will_topic="test/t06/will"`, `will_payload="client_died"`, `will_delay_interval=1`
3. Client B: **не отправлять DISCONNECT** — закрыть сокет (abnormal disconnect)
4. Client A: Loop() ждать 5 сек
5. Проверить: callback получил will message

**Важно**: Will Delay Interval = 1 сек, но broker может задержать delivery. Ждать до 10 сек.

### T07: Keepalive
1. Client: connect с `keep_alive = 3`
2. Не отправлять никаких сообщений 4 секунды
3. Loop() — проверить что PINGREQ отправлен
4. Loop() — проверить что PINGRESP получен
5. Проверить: `IsConnected() == true`

### T08: Flow Control
1. Client: connect с `receive_maximum = 2`
2. Publish QoS 1 msg1 — ok
3. Publish QoS 1 msg2 — ok
4. Publish QoS 1 msg3 — проверить: `m_send_quota` должен быть 0
5. Loop() — получить PUBACK — quota restores
6. Publish QoS 1 msg4 — ok

### T09: Topic Alias
1. Client A: subscribe `test/t09/#`, QoS 0
2. Client B: publish `test/t09/alias` с `topic_alias = 1`
3. Client B: publish `""` с `topic_alias = 1` (reuse)
4. Client A: Loop() — получить 2 сообщения
5. Проверить: оба сообщения topic == "test/t09/alias"

### T10: Subscription Options
1. Client A: subscribe `test/t10` с `no_local = true`, QoS 0
2. Client A: publish `test/t10`, payload "self-msg"
3. Client B: publish `test/t10`, payload "other-msg"
4. Client A: Loop()
5. Проверить:收到了 "other-msg" но **НЕ** получил "self-msg" (no_local)

### T11: Unsubscribe
1. Client A: subscribe `test/t11`
2. Client B: publish `test/t11`, payload "before"
3. Client A: Loop() — получить "before"
4. Client A: unsubscribe `test/t11`
5. Client B: publish `test/t11`, payload "after"
6. Client A: Loop() 2 сек
7. Проверить: **НЕ** получил "after"

### T12: Large Payload
1. Client A: subscribe `test/t12`
2. Client B: publish 1KB (A chars) — Client A получает, проверить len
3. Client B: publish 10KB (B chars) — Client A получает, проверить len
4. Client B: publish 50KB (C chars) — Client A получает, проверить len
5. Проверить: все payload_len совпадают

### T13: UTF-8 Topics
1. Client A: subscribe `тест/t13/топика`
2. Client B: publish `тест/t13/топика`, payload "Привет MQTTFive!"
3. Client A: Loop() — получить
4. Проверить: topic == `тест/t13/топика`
5. Проверить: payload == "Привет MQTTFive!"

### T14: Binary Payload
1. Client A: subscribe `test/t14`
2. Client B: publish `test/t14`, payload = uchar[256] (0x00..0xFF)
3. Client A: Loop() — получить
4. Проверить: payload_len == 256
5. Проверить: каждый byte[i] == i

### T15: Multi Pub/Sub
1. Client A1: subscribe `test/t15`, QoS 0
2. Client A2: subscribe `test/t15`, QoS 0
3. Client A3: subscribe `test/t15`, QoS 0
4. Client B: publish `test/t15`, payload "broadcast"
5. Все A1,A2,A3: Loop()
6. Проверить: все 3 получили payload == "broadcast"
