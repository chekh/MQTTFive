# Architecture

## Layer overview

```
┌─────────────────────────────────────────────────────┐
│  Your code                                          │
│  #include <MQTTFive/MQTTClient.mqh>                 │
├─────────────────────────────────────────────────────┤
│  MQTTClient.mqh                                     │
│  High-level API: Connect, Publish, Subscribe, Loop  │
├─────────────────────────────────────────────────────┤
│  MQTTCodec.mqh                                      │
│  Packet encoding and decoding (MQTT wire format)    │
├─────────────────────────────────────────────────────┤
│  MQTTBuffer.mqh                                     │
│  Binary buffer with read/write position tracking    │
├─────────────────────────────────────────────────────┤
│  MQTTTransport.mqh                                  │
│  TCP/TLS via MQL5 Socket API                        │
└─────────────────────────────────────────────────────┘
```

You only interact with `MQTTClient`. The other three files are internal.

## Source files

### MQTTTypes.mqh (~300 lines)

Shared types and constants used by all other files:

- **Enums**: packet types (`MQTT_PKT_*`), CONNACK reason codes, property IDs
- **Structs**: `MQTTConnectParams`, `MQTTConnackInfo`, `MQTTSubscribeParams`,
  `MQTTSubscriptionOptions`, `MQTTPublishMessage`, `MQTTInflightMessage`,
  `MQTTQos2Incoming`, `MQTTWillProperties`
- **Constants**: connect flags, PUBLISH flags, inflight states

Included automatically by `MQTTClient.mqh`. You reference it when using
parameter structs.

### MQTTBuffer.mqh (~210 lines)

Byte buffer with separate read and write positions. Key operations:

- `WriteByte`, `WriteU16`, `WriteU32`, `WriteVarInt`, `WriteString`, `WriteRawBytes`
- `ReadByte`, `ReadU16`, `ReadU32`, `ReadVarInt`, `ReadString`, `ReadRawBytes`
- `AttachRead(data[], len)` — attach external byte array for reading
- `GetData(result[])` — extract written bytes
- `Reset()` — clear positions

Used by `MQTTCodec` for serialization and deserialization. Not used directly
by application code.

### MQTTTransport.mqh (~130 lines)

Thin wrapper over MQL5 Socket API:

- `Connect()` — `SocketCreate` + `SocketConnect` (+ `SocketTlsHandshake` if TLS)
- `Disconnect()` — `SocketClose`
- `Send()` — `SocketSend` (or `SocketTlsSend`)
- `Receive()` — `SocketRead` (or `SocketTlsRead`)
- `IsConnected()` — `SocketIsConnected`
- `IsReadable()` — `SocketIsReadable`

All timeouts are stored internally in milliseconds.

### MQTTCodec.mqh (~480 lines)

Static class with encode/decode methods for each packet type:

| Method | Direction | Description |
|--------|-----------|-------------|
| `EncodeConnect` | Outgoing | CONNECT with properties and will |
| `DecodeConnackFull` | Incoming | CONNACK with properties |
| `EncodePublishString` | Outgoing | PUBLISH with string payload |
| `EncodePublish` | Outgoing | PUBLISH with binary payload |
| `DecodePublish` | Incoming | PUBLISH (topic, QoS, payload) |
| `EncodePuback` | Outgoing | PUBACK (QoS 1 acknowledgment) |
| `DecodePuback` | Incoming | PUBACK |
| `EncodePubrec` | Outgoing | PUBREC (QoS 2 received) |
| `DecodePubrec` | Incoming | PUBREC |
| `EncodePubrel` | Outgoing | PUBREL (QoS 2 release) |
| `DecodePubrel` | Incoming | PUBREL |
| `EncodePubcomp` | Outgoing | PUBCOMP (QoS 2 complete) |
| `DecodePubcomp` | Incoming | PUBCOMP |
| `EncodeSubscribe` | Outgoing | SUBSCRIBE with options |
| `DecodeSuback` | Incoming | SUBACK |
| `EncodeUnsubscribe` | Outgoing | UNSUBSCRIBE |
| `DecodeUnsuback` | Incoming | UNSUBACK |
| `EncodePingreq` | Outgoing | PINGREQ |
| `EncodeDisconnect` | Outgoing | DISCONNECT (minimal) |
| `EncodeDisconnectWithReason` | Outgoing | DISCONNECT with reason + properties |
| `PacketType` | Utility | Extract packet type from first byte |
| `IsPingresp` | Utility | Check if first byte is PINGRESP |
| `IsDisconnect` | Utility | Check if first byte is DISCONNECT |

### MQTTClient.mqh (~720 lines)

The user-facing class. Contains:

- **State machine**: `MQTT_STATE_DISCONNECTED` → `MQTT_STATE_CONNECTED`
- **Packet ID generator**: auto-incrementing, wraps 0 → 1
- **Inflight tracking**: `m_inflight[]` array for QoS 1/2 messages awaiting ACK
- **QoS 2 incoming**: `m_qos2_incoming[]` for incoming QoS 2 messages awaiting PUBREL
- **Topic alias registry**: `m_alias_ids[]` / `m_alias_topics[]` for outgoing aliases
- **Flow control**: `m_send_quota` decremented on QoS > 0 publish, incremented on ACK

## Event loop

MQTTFive is single-threaded (MQL5 limitation). `Loop()` must be called
regularly from your code:

```
Loop()
  ├── Check if connected
  ├── Keepalive: send PINGREQ if idle too long
  ├── Keepalive: disconnect if no data received (1.5x timeout)
  ├── Retry: resend unacknowledged QoS 1/2 messages
  └── HandleIncomingPacket()
       ├── PUBLISH  → callback (QoS 0) or PUBACK/PUBREC (QoS 1/2)
       ├── PUBACK   → free inflight slot, increment quota
       ├── PUBREC   → send PUBREL
       ├── PUBREL   → callback, send PUBCOMP
       ├── PUBCOMP  → free inflight slot, increment quota
       ├── SUBACK   → decode
       ├── UNSUBACK → decode
       ├── PINGRESP → clear ping flag
       └── DISCONNECT → set disconnected
```

Each `Loop()` call processes **one** incoming packet at most. For high-throughput
scenarios, call `Loop()` multiple times per iteration:

```cpp
while(!IsStopped())
  {
   for(int i = 0; i < 10; i++)
      mqtt.Loop();
   Sleep(100);
  }
```

## QoS 2 flow

The full QoS 2 flow involves two independent handshakes:

**Publisher ↔ Broker:**
```
Publisher                Broker
  │  PUBLISH (QoS 2)     │
  │ ──────────────────►  │
  │  PUBREC              │
  │ ◄──────────────────  │
  │  PUBREL              │
  │ ──────────────────►  │
  │  PUBCOMP             │
  │ ◄──────────────────  │
```

**Broker ↔ Subscriber:**
```
Broker                   Subscriber
  │  PUBLISH (QoS 2)     │
  │ ──────────────────►  │
  │  PUBREC              │
  │ ◄──────────────────  │
  │  PUBREL              │
  │ ──────────────────►  │
  │  PUBCOMP             │
  │ ◄──────────────────  │
```

The message is delivered to the subscriber's callback only when PUBREL is
received. Some brokers (including Mosquitto) hold the message until the
publisher's PUBREL is received. This means both publisher and subscriber need
to call `Loop()` for the message to arrive.

## Memory management

MQL5 uses garbage collection for strings and dynamic arrays. The library uses:

- `MQTTBuffer::m_data[]` — dynamically resized via `ArrayResize`
- `MQTTClient::m_inflight[]` — struct array, grows on QoS > 0 publish
- `MQTTClient::m_qos2_incoming[]` — struct array, grows on QoS 2 receive
- `MQTTClient::m_alias_ids[]` / `m_alias_topics[]` — parallel arrays

All arrays are cleaned up when the `MQTTClient` instance is destroyed.

## File size

| File | Lines | Purpose |
|------|-------|---------|
| MQTTTypes.mqh | ~300 | Types and constants |
| MQTTBuffer.mqh | ~210 | Binary buffer |
| MQTTTransport.mqh | ~130 | TCP/TLS transport |
| MQTTCodec.mqh | ~480 | Packet codec |
| MQTTClient.mqh | ~720 | Client API |
| **Total** | **~1840** | |
