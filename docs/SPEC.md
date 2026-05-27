# MQTTFive — MQTT 5.0 Client Library for MQL5

## 1. Overview

**MQTTFive** — standalone MQTT v5.0 client library for MQL5 (MetaTrader 5).

Properties:
- Pure MQL5, zero external DLL dependencies
- TCP + TLS via native MQL5 Socket API (`SocketCreate`, `SocketConnect`, `SocketSend`, `SocketRead`, `SocketTlsHandshake`)
- MQTT v5.0 protocol (Protocol Version = 0x05)
- Compatible with any MQTT 5.0 broker (Mosquitto >= 5.0, EMQX, HiveMQ, VerneMQ)
- Single-threaded event loop model (call `Loop()` from `OnTick` / service loop)
- Binary-safe payload (`uchar[]`)
- Header-only (`.mqh` files, no compilation step)

## 2. Architecture

```
┌─────────────────────────────────────┐
│          MQTTClient.mqh             │  User API
│  Connect/Publish/Subscribe/Loop     │
├─────────────────────────────────────┤
│          MQTTCodec.mqh              │  Packet encode/decode
│  Encode*/Decode* for each type      │
├─────────────────────────────────────┤
│          MQTTBuffer.mqh             │  Byte buffer (position-based)
│  Read*/Write* with big-endian       │
├─────────────────────────────────────┤
│          MQTTTransport.mqh          │  TCP/TLS socket I/O
│  SocketCreate/Connect/Send/Read     │
├─────────────────────────────────────┤
│          MQTTTypes.mqh              │  Constants, enums, structs
└─────────────────────────────────────┘
```

## 3. File Structure

```
Include/MQTTFive/
  MQTTTypes.mqh       Constants, enums, data structures
  MQTTBuffer.mqh      Byte buffer with read/write position tracking
  MQTTTransport.mqh   TCP/TLS transport over MQL5 Socket API
  MQTTCodec.mqh       Packet encoding (build) and decoding (parse)
  MQTTClient.mqh      High-level client with connect/publish/subscribe/loop
```

## 4. Design Decisions

### 4.1. Binary-safe payload

All payload data uses `uchar[]`. The library never converts payload through `string` (MQL5 UTF-16).
Two `Publish` overloads:
- `Publish(topic, string_payload)` — convenience for JSON/text, converts UTF-16 to UTF-8 internally
- `Publish(topic, uchar_payload[], len)` — raw bytes, zero-copy

### 4.2. UTF-8 encoding

MQL5 `string` = UTF-16. MQTT requires UTF-8. The library uses `StringToCharArray(s, arr, 0, WHOLE_ARRAY, CP_UTF8)` for correct conversion. This handles ASCII, Cyrillic, and other BMP characters correctly. The 2-byte length prefix in MQTT's UTF-8 Encoded String is the **byte length** (not character count).

### 4.3. Properties — Phase 1 = empty

All packets send Properties Length = `0x00` (no properties). This is valid MQTT 5.0.
Properties support is deferred to Phase 2 (future enhancement).

### 4.4. QoS scope

Phase 1 implements:
- QoS 0 publish and subscribe (fire-and-forget)
- PUBACK send for incoming QoS 1 messages (minimal compliance)
- No QoS 2 (PUBREC/PUBREL/PUBCOMP flow) in Phase 1

### 4.5. No inheritance, no interfaces

Flat structures and classes. No `interface`, no deep hierarchies.
Data (structs) separated from logic (static codec methods, transport class, client class).

### 4.6. No global state

No static instance registries, no global callbacks. Callback is per-client instance.

### 4.7. Transport = MQL5 native sockets

Only `SocketCreate`, `SocketConnect`, `SocketSend`, `SocketRead`, `SocketIsConnected`, `SocketIsReadable`, `SocketClose` and their TLS equivalents (`SocketTlsHandshake`, `SocketTlsSend`, `SocketTlsRead`, `SocketTlsCertificate`).
No DLL, no WinAPI, no external libraries. Works on any MT5 VPS.

## 5. API Specification

### 5.1. MQTTTypes.mqh

```cpp
// Packet type values (already shifted << 4, ready for Fixed Header byte 1)
enum ENUM_MQTT_PKT {
    MQTT_PKT_CONNECT     = 0x10,
    MQTT_PKT_CONNACK     = 0x20,
    MQTT_PKT_PUBLISH     = 0x30,
    MQTT_PKT_PUBACK      = 0x40,
    MQTT_PKT_PUBREC      = 0x50,
    MQTT_PKT_PUBREL      = 0x62,
    MQTT_PKT_PUBCOMP     = 0x70,
    MQTT_PKT_SUBSCRIBE   = 0x82,
    MQTT_PKT_SUBACK      = 0x90,
    MQTT_PKT_UNSUBSCRIBE = 0xA2,
    MQTT_PKT_UNSUBACK    = 0xB0,
    MQTT_PKT_PINGREQ     = 0xC0,
    MQTT_PKT_PINGRESP    = 0xD0,
    MQTT_PKT_DISCONNECT  = 0xE0,
    MQTT_PKT_AUTH        = 0xF0
};

enum ENUM_MQTT_STATE {
    MQTT_STATE_DISCONNECTED = -1,
    MQTT_STATE_CONNECTED    =  0
};

// CONNACK reason codes (subset — most common)
enum ENUM_MQTT_CONNACK {
    MQTT_CONNACK_SUCCESS                   = 0x00,
    MQTT_CONNACK_UNSPECIFIED_ERROR         = 0x80,
    MQTT_CONNACK_MALFORMED_PACKET          = 0x81,
    MQTT_CONNACK_PROTOCOL_ERROR            = 0x82,
    MQTT_CONNACK_UNSUPPORTED_VERSION       = 0x84,
    MQTT_CONNACK_INVALID_CLIENT_ID         = 0x85,
    MQTT_CONNACK_BAD_CREDENTIALS           = 0x86,
    MQTT_CONNACK_NOT_AUTHORIZED            = 0x87,
    MQTT_CONNACK_SERVER_UNAVAILABLE        = 0x88,
    MQTT_CONNACK_SERVER_BUSY               = 0x89,
    MQTT_CONNACK_BANNED                    = 0x8A
};

struct MQTTConnectParams {
    string  client_id;
    string  username;
    string  password;
    ushort  keep_alive;
    bool    clean_start;
    // Will (optional)
    string  will_topic;
    string  will_payload;
    uchar   will_qos;
    bool    will_retain;

    void Init() {
        client_id = ""; username = ""; password = "";
        keep_alive = 60; clean_start = true;
        will_topic = ""; will_payload = ""; will_qos = 0; will_retain = false;
    }
};

// Connect Flags bit masks (Section 3.1.2.3)
#define MQTT_FLAG_CLEAN_START   0x02
#define MQTT_FLAG_WILL          0x04
#define MQTT_FLAG_WILL_QOS_MASK 0x18
#define MQTT_FLAG_WILL_RETAIN   0x20
#define MQTT_FLAG_PASSWORD      0x40
#define MQTT_FLAG_USERNAME      0x80

struct MQTTPublishMessage {
    string  topic;
    uchar   payload[];
    uint    payload_len;
    uchar   qos;
    bool    retain;
    bool    dup;
    ushort  packet_id;
};

struct MQTTSubscribeParams {
    string  topic_filter;
    uchar   qos;
};
```

### 5.2. MQTTBuffer.mqh

```cpp
class MQTTBuffer {
public:
    MQTTBuffer();
    void Reset();

    // Writing
    void WriteByte(uchar b);
    void WriteU16(ushort v);
    void WriteU32(uint v);
    void WriteVarInt(uint v);
    void WriteString(string s);       // UTF-8 with 2-byte byte-length prefix (via CP_UTF8)
    void WriteRawBytes(uchar &src[], uint len);

    // Reading
    bool ReadByte(uchar &result);
    bool ReadU16(ushort &result);
    bool ReadU32(uint &result);
    uint ReadVarInt(bool &ok);
    bool ReadString(string &result);
    bool ReadRawBytes(uchar &result[], uint len);
    void SkipBytes(uint count);

    // Buffer management
    void AttachRead(uchar &data[], uint len);
    void GetData(uchar &result[]);
    uint WritePosition();
    uint ReadPosition();
    uint Remaining();
};
```

### 5.3. MQTTTransport.mqh

```cpp
class MQTTTransport {
public:
    MQTTTransport();
    ~MQTTTransport();

    bool Connect(string host, ushort port, uint timeout_sec, bool useTLS);
    bool Disconnect();
    bool Send(uchar &data[], uint len);
    int  Receive(uchar &data[], uint max_len);
    bool IsConnected();
    bool IsReadable();
    int  GetSocket();
};
```

### 5.4. MQTTCodec.mqh

```cpp
class MQTTCodec {
public:
    // Encoding
    static void EncodeConnect(MQTTConnectParams &params, MQTTBuffer &buf);
    static void EncodePublish(string topic, uchar &payload[], uint payload_len,
                              uchar qos, bool retain, ushort packet_id,
                              MQTTBuffer &buf);
    static void EncodePublishString(string topic, string payload,
                                    uchar qos, bool retain, ushort packet_id,
                                    MQTTBuffer &buf);
    static void EncodeSubscribe(ushort packet_id, MQTTSubscribeParams &params,
                                MQTTBuffer &buf);
    static void EncodeUnsubscribe(ushort packet_id, string &topic,
                                  MQTTBuffer &buf);
    static void EncodePuback(ushort packet_id, MQTTBuffer &buf);
    static void EncodePingreq(MQTTBuffer &buf);
    static void EncodeDisconnect(MQTTBuffer &buf);

    // Decoding helpers
    static uchar PacketType(uchar first_byte);
    static bool DecodeConnack(MQTTBuffer &buf, uchar &reason_code,
                              bool &session_present);
    static bool DecodePublish(MQTTBuffer &buf, uchar first_byte,
                              MQTTPublishMessage &msg);
    static bool DecodeSuback(MQTTBuffer &buf, ushort &packet_id,
                             uchar &reason_code);
    static bool DecodePuback(MQTTBuffer &buf, ushort &packet_id,
                             uchar &reason_code);
    static bool IsPingresp(uchar first_byte);
    static bool IsDisconnect(uchar first_byte);
};
```

### 5.5. MQTTClient.mqh

```cpp
typedef void (*MQTTMessageCallback)(string &topic, uchar &payload[], uint payload_len);

class MQTTClient {
private:
    MQTTTransport  m_transport;
    MQTTBuffer     m_write_buf;
    MQTTBuffer     m_read_buf;
    ENUM_MQTT_STATE m_state;
    ushort         m_next_pkt_id;
    datetime       m_last_out;
    datetime       m_last_in;
    ushort         m_keep_alive;
    MQTTMessageCallback m_callback;
    int            m_last_error;
    string         m_last_error_msg;

    ushort NextPacketId();
    bool SendBuffer();
    bool HandleConnack();
    bool HandleIncomingPacket();
    void SetError(int code, string msg);

public:
    MQTTClient();
    ~MQTTClient();

    void SetCallback(MQTTMessageCallback callback);
    void SetKeepAlive(ushort seconds);

    bool Connect(string host, ushort port, MQTTConnectParams &params,
                 bool useTLS = false, uint timeout = 15);
    bool Disconnect();

    bool Publish(string topic, string payload, uchar qos = 0, bool retain = false);
    bool Publish(string topic, uchar &payload[], uint payload_len,
                 uchar qos = 0, bool retain = false);
    bool Subscribe(string topic, uchar qos = 0);
    bool Unsubscribe(string topic);

    bool Loop();

    bool IsConnected();
    string GetLastError();
    int GetLastErrorCode();
};
```

## 6. Wire Format — MQTT 5.0 Packet Encoding

### 6.1. CONNECT

```
Fixed Header:
  Byte 1: 0x10
  Byte 2+: Remaining Length (VBI)

Variable Header:
  [0x00 0x04 'M' 'Q' 'T' 'T']   Protocol Name (6 bytes)
  [0x05]                          Protocol Version
  [Connect Flags]                 1 byte (see below)
  [Keep Alive MSB LSB]           2 bytes
  [0x00]                          Properties Length = 0

Payload:
  [Client ID (UTF-8 String)]
  [Will Properties (0x00)]        if Will Flag = 1
  [Will Topic (UTF-8 String)]     if Will Flag = 1
  [Will Payload (Binary Data)]    if Will Flag = 1
  [User Name (UTF-8 String)]      if User Name Flag = 1
  [Password (Binary Data)]        if Password Flag = 1

Connect Flags:
  Bit 7: User Name Flag
  Bit 6: Password Flag
  Bit 5: Will Retain
  Bit 4-3: Will QoS
  Bit 2: Will Flag
  Bit 1: Clean Start
  Bit 0: Reserved (must be 0)
```

### 6.2. CONNACK (received)

```
Fixed Header:
  Byte 1: 0x20
  Byte 2+: Remaining Length (VBI)

Variable Header:
  Byte 1: Connect Acknowledge Flags (bit 0 = Session Present)
  Byte 2: Reason Code
  Byte 3+: Properties Length (VBI) + Properties
```

### 6.3. PUBLISH (send)

```
Fixed Header:
  Byte 1: 0x30 | (DUP<<3) | (QoS<<1) | RETAIN
  Byte 2+: Remaining Length (VBI)

Variable Header:
  [Topic Name (UTF-8 String)]
  [Packet Identifier MSB LSB]     if QoS > 0
  [0x00]                          Properties Length = 0

Payload:
  [raw bytes]                     Application message
```

### 6.4. PUBLISH (receive)

```
Fixed Header:
  Byte 1: 0x30 | flags
  Byte 2+: Remaining Length (VBI)

Variable Header:
  [Topic Name (UTF-8 String)]
  [Packet Identifier MSB LSB]     if QoS > 0
  [Properties Length (VBI)]       skip properties
  [Payload bytes]
```

### 6.5. PUBACK (send for incoming QoS 1)

```
Fixed Header:
  Byte 1: 0x40
  Byte 2: 0x02 (Remaining Length)

Variable Header:
  [Packet ID MSB] [Packet ID LSB]
```

Note: MQTT 5.0 allows omitting Reason Code + Properties if Remaining Length = 2.
We use the minimal form (no Reason Code, no Properties).

### 6.6. SUBSCRIBE

```
Fixed Header:
  Byte 1: 0x82
  Byte 2+: Remaining Length (VBI)

Variable Header:
  [Packet ID MSB] [Packet ID LSB]
  [0x00]                          Properties Length = 0

Payload:
  [Topic Filter (UTF-8 String)]
  [Subscription Options]          1 byte:
    Bits 1-0: Maximum QoS
    Bit 2: No Local (0)
    Bit 3: Retain As Published (0)
    Bits 5-4: Retain Handling (0)
    Bits 7-6: Reserved (0)
```

### 6.7. UNSUBSCRIBE

```
Fixed Header:
  Byte 1: 0xA2
  Byte 2+: Remaining Length (VBI)

Variable Header:
  [Packet ID MSB] [Packet ID LSB]
  [0x00]                          Properties Length = 0

Payload:
  [Topic Filter (UTF-8 String)]
```

### 6.8. PINGREQ

```
Byte 1: 0xC0
Byte 2: 0x00
```

### 6.9. DISCONNECT

```
Byte 1: 0xE0
Byte 2: 0x00
```

Note: Remaining Length = 0, omitting Reason Code and Properties.

## 7. Loop() State Machine

```
Loop() called every tick
  │
  ├─ IsConnected() == false → return false
  │
  ├─ Keepalive check:
  │   if (now - last_out > keep_alive && now - last_in > keep_alive):
  │     send PINGREQ
  │     if outstanding ping → timeout → disconnect
  │
  ├─ Read incoming packet (if socket readable):
  │   read first byte → determine packet type
  │   read remaining length (VBI)
  │   read packet body into buffer
  │   dispatch by type:
  │     CONNACK  → decode, store session state
  │     PUBLISH  → decode topic + payload, invoke callback,
  │                send PUBACK if QoS 1
  │     SUBACK   → decode packet_id + reason_code
  │     PUBACK   → decode packet_id + reason_code
  │     PINGRESP → clear ping outstanding flag
  │     DISCONNECT → close connection
  │
  └─ return true
```

## 8. Keep Alive Behavior

Per MQTT 5.0 spec:
- `keep_alive` sent in CONNECT (seconds, 0 = disabled)
- Client MUST send a packet within `keep_alive` seconds
- If no data packet to send, Client sends PINGREQ
- Server closes connection if no packet received within `1.5 * keep_alive`
- Default: 60 seconds

Implementation:
- `m_last_out` = timestamp of last sent packet
- `m_last_in` = timestamp of last received packet
- On each `Loop()`: if `now - m_last_out >= keep_alive`, send PINGREQ (trigger on send only)
- If PINGREQ outstanding and `now - m_last_in >= keep_alive * 1.5`, disconnect
- Per MQTT 5.0 spec: Server closes connection if no packet received within `1.5 * keep_alive`

## 9. Error Handling

| Scenario | Action |
|----------|--------|
| Socket connect failed | Set error, return false from Connect() |
| CONNACK reason code >= 0x80 | Set error, close socket, return false |
| Socket disconnected during Loop | Set error, return false |
| Partial socket read | Loop until all bytes received, disconnect on timeout |
| Malformed packet (invalid remaining length) | Disconnect, set error |
| Unknown packet type | Skip, log warning |
| Buffer overflow (payload > max buffer) | Set error, return false from Publish() |

## 10. Limits

| Parameter | Value | Notes |
|-----------|-------|-------|
| Max payload size | 65535 bytes | MQL5 socket buffer limit |
| Max topic length | 65535 bytes | MQTT spec limit |
| Max packet size | ~65535 bytes | Phase 1 limit |
| Keep alive range | 0-65535 seconds | 0 = disabled |
| Packet ID range | 1-65535 | Auto-incrementing |
| Initial buffer capacity | 4096 bytes | Grows dynamically up to 2x |
| Max subscriptions per SUBSCRIBE | 1 | Phase 1 limitation |

## 11. Thread Safety

Not thread-safe. Single-threaded event loop. One `Loop()` call per tick.
Multiple `MQTTClient` instances allowed (each has own socket), but must be
looped sequentially.

## 12. Future Phases

### Phase 2: Properties
- CONNECT properties: Session Expiry Interval, Receive Maximum, Max Packet Size, Topic Alias Maximum
- CONNACK properties: parse and store (Server Keep Alive, Topic Alias Maximum, etc.)
- PUBLISH properties: Content-Type, Topic Alias, Correlation Data, Response Topic
- User Properties support

### Phase 3: QoS 1+2
- QoS 1: inflight tracking, retry on PUBACK timeout
- QoS 2: PUBREC/PUBREL/PUBCOMP flow
- Receive Maximum flow control

### Phase 4: Advanced
- Will messages with Will Properties
- AUTH (enhanced authentication)
- Shared subscriptions
- Subscription identifiers
- Auto-reconnect with backoff

## 13. Migration from PubSubClient + MQTTClient

Current usage pattern (7 services + 1 expert):
```cpp
class CMyService : public MQTTClient {
    // inherits transport, heartbeat, pub/sub
};
```

New pattern (composition):
```cpp
class CMyService {
    MQTTClient m_mqtt;  // member, not base class

    bool Start() {
        MQTTConnectParams params;
        params.Init();
        params.client_id = "service_" + login;
        params.username = user;
        params.password = pass;
        m_mqtt.SetCallback(OnMessage);
        return m_mqtt.Connect(host, port, params, useTLS);
    }

    bool Loop() {
        return m_mqtt.Loop();
    }

    static void OnMessage(string &topic, uchar &payload[], uint payload_len) {
        string msg = CharArrayToString(payload, 0, payload_len);
        // route by topic
    }
};
```

Key differences:
- Composition over inheritance
- No static instance registry
- No virtual methods
- No built-in heartbeat (service manages its own)
- Raw `uchar[]` callback (service decodes to string if needed)
