# MQTTFive Phase 2-3 Design — Full MQTT 5.0 Compliance (G1-G11)

**Date**: 2026-05-27
**Scope**: Gaps G1-G11 from MQTT 5.0 OASIS Standard compliance analysis
**Approach**: Incremental — 3 feature branches, each independently testable

---

## 1. Gap Summary

| # | Gap | Branch | Priority |
|---|-----|--------|----------|
| G1 | UNSUBACK decode + handling | feat/properties | Critical |
| G2 | CONNACK property parsing | feat/properties | Critical |
| G6 | CONNECT properties (Session Expiry, Receive Maximum) | feat/properties | Important |
| G7 | CONNECT property: Maximum Packet Size | feat/properties | Important |
| G9 | DISCONNECT with Reason Code + Session Expiry | feat/properties | Important |
| G10 | Will Properties (Will Delay Interval, etc.) | feat/properties | Important |
| G11 | Subscription Options full support | feat/properties | Important |
| G3 | QoS 2 flow (PUBREC/PUBREL/PUBCOMP) | feat/qos2-flow | Critical |
| G4 | Flow control (Receive Maximum quota) | feat/qos2-flow | Critical |
| G5 | QoS 1 inflight tracking + retry | feat/qos2-flow | Critical |
| G8 | Topic Alias | feat/topic-alias | Important |

---

## 2. Branch 1: feat/properties

### 2.1. New Types in MQTTTypes.mqh

```cpp
enum ENUM_MQTT_PROPERTY_ID
  {
   MQTT_PROP_SESSION_EXPIRY_INTERVAL    = 0x11,
   MQTT_PROP_RECEIVE_MAXIMUM            = 0x21,
   MQTT_PROP_MAXIMUM_QOS                = 0x24,
   MQTT_PROP_RETAIN_AVAILABLE           = 0x25,
   MQTT_PROP_MAXIMUM_PACKET_SIZE        = 0x27,
   MQTT_PROP_ASSIGNED_CLIENT_ID         = 0x12,
   MQTT_PROP_TOPIC_ALIAS_MAXIMUM        = 0x22,
   MQTT_PROP_TOPIC_ALIAS                = 0x23,
   MQTT_PROP_SERVER_KEEP_ALIVE          = 0x13,
   MQTT_PROP_WILL_DELAY_INTERVAL        = 0x18,
   MQTT_PROP_PAYLOAD_FORMAT_INDICATOR   = 0x01,
   MQTT_PROP_MESSAGE_EXPIRY_INTERVAL    = 0x02,
   MQTT_PROP_CONTENT_TYPE               = 0x03,
   MQTT_PROP_USER_PROPERTY              = 0x26,
   MQTT_PROP_REASON_STRING              = 0x1F,
   MQTT_PROP_REQUEST_RESPONSE_INFO      = 0x19,
   MQTT_PROP_REQUEST_PROBLEM_INFO       = 0x17
  };

enum ENUM_MQTT_PROPERTY_TYPE
  {
   MQTT_PROPTYPE_BYTE       = 1,
   MQTT_PROPTYPE_U16        = 2,
   MQTT_PROPTYPE_U32        = 4,
   MQTT_PROPTYPE_STRING     = 6,
   MQTT_PROPTYPE_STRING_PAIR= 8,
   MQTT_PROPTYPE_BINARY     = 7,
   MQTT_PROPTYPE_VBI        = 11
  };

struct MQTTConnackInfo
  {
   bool              session_present;
   uchar             reason_code;
   uint              session_expiry_interval;
   ushort            receive_maximum;
   uchar             maximum_qos;
   bool              retain_available;
   uint              maximum_packet_size;
   string            assigned_client_id;
   ushort            topic_alias_maximum;
   ushort            server_keep_alive;
   bool              has_session_expiry;
   bool              has_receive_maximum;
   bool              has_maximum_qos;
   bool              has_retain_available;
   bool              has_maximum_packet_size;
   bool              has_assigned_client_id;
   bool              has_topic_alias_maximum;
   bool              has_server_keep_alive;

   void              Init()
     {
      session_present = false; reason_code = 0xFF;
      session_expiry_interval = 0; receive_maximum = 65535;
      maximum_qos = 2; retain_available = true;
      maximum_packet_size = 0; assigned_client_id = "";
      topic_alias_maximum = 0; server_keep_alive = 0;
      has_session_expiry = false; has_receive_maximum = false;
      has_maximum_qos = false; has_retain_available = false;
      has_maximum_packet_size = false; has_assigned_client_id = false;
      has_topic_alias_maximum = false; has_server_keep_alive = false;
     }
  };

struct MQTTWillProperties
  {
   uint              will_delay_interval;
   uchar             payload_format_indicator;
   uint              message_expiry_interval;
   string            content_type;

   void              Init()
     {
      will_delay_interval = 0;
      payload_format_indicator = 0;
      message_expiry_interval = 0;
      content_type = "";
     }
  };

struct MQTTSubscriptionOptions
  {
   uchar             maximum_qos;
   bool              no_local;
   bool              retain_as_published;
   uchar             retain_handling;

   void              Init()
     {
      maximum_qos = 0; no_local = false;
      retain_as_published = false; retain_handling = 0;
     }

   uchar             ToByte() const
     {
      return (uchar)(maximum_qos & 0x03)
           | ((no_local ? 1 : 0) << 2)
           | ((retain_as_published ? 1 : 0) << 3)
           | ((retain_handling & 0x03) << 4);
     }
  };
```

### 2.2. MQTTConnectParams Update

Add `session_expiry_interval`, `receive_maximum`, `maximum_packet_size`, `topic_alias_maximum`, and `MQTTWillProperties will_props` fields. Update `Init()` with defaults.

### 2.3. MQTTCodec Changes

**Encoding:**
- `EncodeConnect()`: Write CONNECT properties block (non-zero Properties Length with actual properties), Will Properties block if Will is set.
- `EncodeSubscribe()`: Replace `qos` byte with `MQTTSubscriptionOptions::ToByte()`.
- `EncodeDisconnect()`: Add Reason Code + optional Session Expiry Interval property.

**Decoding:**
- `DecodeConnack()`: Replace with `DecodeConnackFull(MQTTBuffer &buf, MQTTConnackInfo &info)` — parse all properties into struct.
- `DecodeUnsuback()`: New method — decode packet_id + skip properties + read reason codes.
- `DecodeProperties()`: New private helper — iterate property block, extract known IDs, skip unknown.

### 2.4. MQTTClient Changes

- `HandleConnack()` uses `MQTTConnackInfo` instead of raw reason_code.
- Store `m_connack_info` as member — accessible via `GetConnackInfo()`.
- `m_keep_alive` overridden by `server_keep_alive` if present.
- `Loop()` checks `m_connack_info.receive_maximum` before sending QoS>0 messages.
- `Loop()` checks `m_connack_info.maximum_packet_size` before sending.
- `HandleIncomingPacket()` dispatches `MQTT_PKT_UNSUBACK`.
- `Disconnect(uchar reason_code)` overload with optional Session Expiry.

### 2.5. Files Changed

| File | Change |
|------|--------|
| `MQTTTypes.mqh` | +80 lines (new enums, structs) |
| `MQTTBuffer.mqh` | unchanged |
| `MQTTTransport.mqh` | unchanged |
| `MQTTCodec.mqh` | +200 lines (properties encoding/decoding, UNSUBACK) |
| `MQTTClient.mqh` | +80 lines (CONNACK info storage, server limits enforcement) |

**Estimated total**: ~360 lines added

---

## 3. Branch 2: feat/qos2-flow

### 3.1. New Types in MQTTTypes.mqh

```cpp
struct MQTTInflightMessage
  {
   ushort            packet_id;
   uchar             qos;
   string            topic;
   uchar             payload[];
   uint              payload_len;
   bool              retain;
   datetime          sent_time;
   uchar             state; // 0=idle, 1=pending_puback, 2=pending_pubrec, 3=pending_pubrel, 4=pending_pubcomp
  };
```

### 3.2. MQTTCodec Changes

- `EncodePubrec(ushort packet_id)` — send PUBREC for incoming QoS 2 PUBLISH.
- `EncodePubrel(ushort packet_id)` — send PUBREL after receiving PUBREC.
- `EncodePubcomp(ushort packet_id)` — send PUBCOMP after receiving PUBREL.
- `DecodePubrec(MQTTBuffer &buf, ushort &packet_id, uchar &reason_code)` — decode incoming PUBREC.
- `DecodePubrel(MQTTBuffer &buf, ushort &packet_id, uchar &reason_code)` — decode incoming PUBREL.
- `DecodePubcomp(MQTTBuffer &buf, ushort &packet_id, uchar &reason_code)` — decode incoming PUBCOMP.

### 3.3. MQTTClient Changes

**QoS 1 inflight tracking:**
- `MQTTInflightMessage m_inflight[]` — array of sent QoS 1/2 messages awaiting ACK.
- `Publish()` with QoS > 0: store message in `m_inflight`, set `state=1` (pending_puback).
- On PUBACK receive: remove from inflight array.
- On Loop() keepalive check: if inflight message `sent_time + retry_timeout < now`, resend with DUP=1.

**QoS 2 send flow:**
- Publish QoS 2: store in inflight with `state=2` (pending_pubrec).
- On PUBREC receive: send PUBREL, change state to `state=3` (pending_pubcomp).
- On PUBCOMP receive: remove from inflight.

**QoS 2 receive flow:**
- Incoming QoS 2 PUBLISH: send PUBREC, store message in `m_qos2_incoming[]`.
- Incoming PUBREL for stored message: deliver to callback, send PUBCOMP, remove from store.

**Flow control:**
- `m_send_quota` — decremented on QoS>0 publish, incremented on PUBACK/PUBCOMP receive.
- Initialized from `m_connack_info.receive_maximum` (default 65535).
- If `m_send_quota == 0`, `Publish()` returns false with error "send quota exceeded".

### 3.4. Files Changed

| File | Change |
|------|--------|
| `MQTTTypes.mqh` | +15 lines (MQTTInflightMessage) |
| `MQTTBuffer.mqh` | unchanged |
| `MQTTTransport.mqh` | unchanged |
| `MQTTCodec.mqh` | +100 lines (PUBREC/PUBREL/PUBCOMP encode/decode) |
| `MQTTClient.mqh` | +250 lines (inflight, QoS 2 state machine, flow control, retry) |

**Estimated total**: ~365 lines added

---

## 4. Branch 3: feat/topic-alias

### 4.1. New Types in MQTTTypes.mqh

```cpp
struct MQTTTopicAliasEntry
  {
   ushort            alias;
   string            topic;
  };
```

### 4.2. MQTTCodec Changes

- `EncodePublish()` / `EncodePublishString()`: If topic alias provided and topic matches alias, write empty topic string + Topic Alias property. If new alias, write topic + Topic Alias property.
- `DecodePublish()`: Parse Topic Alias property, maintain alias → topic mapping.

### 4.3. MQTTClient Changes

- `m_topic_aliases[]` — array of alias entries (max = `m_connack_info.topic_alias_maximum`).
- `Publish()` overloads: new optional `ushort topic_alias` parameter.
- `HandleIncomingPacket()`: resolve incoming topic alias before callback.

### 4.4. Files Changed

| File | Change |
|------|--------|
| `MQTTTypes.mqh` | +5 lines |
| `MQTTCodec.mqh` | +40 lines |
| `MQTTClient.mqh` | +60 lines |

**Estimated total**: ~105 lines added

---

## 5. Testing — MQTTFiveTestFull.mq5

Single script with `input int TestGroup`:

| Group | Tests | Branch |
|-------|-------|--------|
| 0 | All tests | — |
| 1 | Properties: CONNECT with Session Expiry + Receive Max + Max Packet Size. Verify CONNACK props parsed (Server Keep Alive, Topic Alias Max, Max QoS). DISCONNECT with Session Expiry. | feat/properties |
| 2 | Will Properties: CONNECT with Will + Will Delay + Content Type. Verify broker receives Will on disconnect. | feat/properties |
| 3 | Subscription Options: Subscribe with No Local, Retain As Published, Retain Handling. Verify SUBACK reason codes. | feat/properties |
| 4 | UNSUBACK: Subscribe, then Unsubscribe, verify UNSUBACK received with correct packet_id. | feat/properties |
| 5 | QoS 2 send: Publish QoS 2, verify PUBREC → PUBREL → PUBCOMP flow. | feat/qos2-flow |
| 6 | QoS 2 receive: Subscribe QoS 2, receive QoS 2 message, verify PUBREC → PUBREL → PUBCOMP. | feat/qos2-flow |
| 7 | QoS 1 inflight: Publish QoS 1, verify PUBACK clears inflight. Simulate retry timeout. | feat/qos2-flow |
| 8 | Flow control: Set Receive Maximum = 2, publish 3 messages, verify 3rd blocked until PUBACK. | feat/qos2-flow |
| 9 | Topic Alias: Publish same topic with alias, verify second publish has empty topic. Receive with alias. | feat/topic-alias |

Each test prints `PASS` / `FAIL` to MT5 Journal. No assertions — just logging for manual verification.

---

## 6. Implementation Order

```
feat/properties → merge → feat/qos2-flow → merge → feat/topic-alias → merge
```

Each branch is independently compilable and testable. Test groups 1-4 work after feat/properties, groups 5-8 after feat/qos2-flow, group 9 after feat/topic-alias.

---

## 7. Estimated Total

| Branch | New Lines | Total Library Size |
|--------|-----------|-------------------|
| feat/properties | ~360 | ~1,600 |
| feat/qos2-flow | ~365 | ~1,965 |
| feat/topic-alias | ~105 | ~2,070 |
| Test script | ~200 | — |

Final library: ~2,070 lines across 5 files.
