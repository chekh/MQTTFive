<div align="center">
  <img src="docs/mqtt5_logo.png" alt="MQTTFive" width="200"/>
</div>

# MQTTFive — MQTT 5.0 Client for MQL5

Pure MQL5 implementation of the MQTT 5.0 protocol. Zero DLL dependencies.
TCP and TLS via native MQL5 Socket API.

## Features

- **MQTT v5.0** — full protocol version 5 support
- **QoS 0, 1, 2** — complete publish/subscribe flow with inflight tracking
- **CONNECT properties** — session expiry, receive maximum, topic alias maximum, max packet size
- **CONNACK parsing** — receive maximum, maximum QoS, retain available, topic alias maximum, server keep alive, assigned client ID
- **Will messages** — with will delay interval, payload format indicator, message expiry, content type
- **Topic Alias** — register and reuse topic aliases for outgoing PUBLISH
- **Flow Control** — Receive Maximum enforcement, send quota tracking
- **Subscription Options** — maximum QoS, no local, retain as published, retain handling
- **DISCONNECT with reason** — reason code + session expiry interval
- **Keepalive** — automatic PINGREQ/PINGRESP
- **Binary payload** — `uchar[]` without encoding assumptions
- **UTF-8** — `CP_UTF8` for topics and string payloads
- **TLS** — via `SocketTlsHandshake`
- **Auto-retry** — QoS 1/2 message retry with configurable timeout

## Requirements

- MetaTrader 5 terminal (build 3390+)
- MQTT 5.0 compatible broker (Mosquitto >= 5.0, EMQX, HiveMQ)

## Installation

1. Copy `Include/MQTTFive/` to your MT5 `MQL5/Include/` directory
2. Optionally copy `Scripts/MQTTFive/` to `MQL5/Scripts/` for test scripts
3. Compile your EA or script in MetaEditor

## Quick Start

```cpp
#include <MQTTFive/MQTTClient.mqh>

MQTTClient *client;

void OnMessage(string &topic, uchar &payload[], uint payload_len)
  {
   string msg = CharArrayToString(payload, 0, (int)payload_len, CP_UTF8);
   Print("Received: ", topic, " = ", msg);
  }

void OnStart()
  {
   client = new MQTTClient();
   client.SetCallback(OnMessage);

   MQTTConnectParams params;
   params.Init();
   params.client_id = "mql5_client";
   params.keep_alive = 60;
   params.clean_start = true;

   if(client.Connect("127.0.0.1", 1883, params))
     {
      client.Subscribe("sensors/#", 0);

      while(!IsStopped())
        {
         client.Publish("sensors/temp", "22.5", 0);
         client.Loop();
         Sleep(1000);
        }

      client.Disconnect();
     }

   delete client;
  }
```

## API Reference

### MQTTClient

#### Connection

| Method | Description |
|--------|-------------|
| `Connect(host, port, params, useTLS, timeout)` | Connect to broker. Returns `true` on success |
| `Disconnect()` | Send DISCONNECT and close TCP |
| `Disconnect(reason_code, session_expiry)` | Send DISCONNECT with MQTT 5.0 reason code and session expiry |
| `ForceDisconnect()` | Close TCP without DISCONNECT (triggers Will message) |
| `IsConnected()` | Check connection state |
| `Loop()` | Process incoming packets, keepalive, retries. Call in main loop |
| `GetConnackInfo()` | Returns `MQTTConnackInfo` with broker properties |
| `GetLastError()` | Returns last error message string |

#### Publishing

| Method | Description |
|--------|-------------|
| `Publish(topic, payload_string, qos, retain)` | Publish UTF-8 string payload |
| `Publish(topic, payload[], payload_len, qos, retain)` | Publish binary `uchar[]` payload |
| `Publish(topic, payload_string, qos, retain, topic_alias)` | Publish with Topic Alias |

#### Subscribing

| Method | Description |
|--------|-------------|
| `Subscribe(topic, qos)` | Subscribe with maximum QoS |
| `Subscribe(params)` | Subscribe with full `MQTTSubscriptionOptions` |
| `Unsubscribe(topic)` | Unsubscribe from topic filter |

#### Configuration

| Method | Description |
|--------|-------------|
| `SetCallback(callback)` | Set message received callback |
| `SetKeepAlive(seconds)` | Override keepalive interval |
| `SetLog(enable)` | Enable/disable debug logging |

### Data Structures

#### MQTTConnectParams

```cpp
MQTTConnectParams params;
params.Init();
params.client_id              = "my_client";
params.username               = "user";
params.password               = "pass";
params.keep_alive             = 60;
params.clean_start            = true;
params.session_expiry_interval = 0;
params.receive_maximum        = 65535;
params.maximum_packet_size    = 0;
params.topic_alias_maximum    = 0;
params.will_topic             = "clients/status";
params.will_payload           = "offline";
params.will_qos               = 0;
params.will_retain            = false;
params.will_props.will_delay_interval       = 0;
params.will_props.payload_format_indicator  = 0;
params.will_props.message_expiry_interval   = 0;
params.will_props.content_type              = "";
```

#### MQTTSubscriptionOptions

```cpp
MQTTSubscribeParams params;
params.Init();
params.topic_filter = "sensors/#";
params.options.maximum_qos       = 2;
params.options.no_local          = false;
params.options.retain_as_published = false;
params.options.retain_handling   = 0;
```

#### MQTTConnackInfo

Parsed from broker's CONNACK response:

```cpp
MQTTConnackInfo info = client.GetConnackInfo();
info.reason_code               // 0x00 = success
info.session_present           // Session Present flag
info.has_receive_maximum       // true if broker sent Receive Maximum
info.receive_maximum           // Broker's Receive Maximum
info.has_maximum_qos           // true if broker sent Maximum QoS
info.maximum_qos               // Broker's Maximum QoS
info.has_retain_available      // true if broker supports retain
info.retain_available           // Broker supports retain
info.has_topic_alias_maximum   // true if broker supports aliases
info.topic_alias_maximum       // Max alias value
info.has_server_keep_alive     // true if broker overrode keepalive
info.server_keep_alive         // Broker's keepalive value
info.has_maximum_packet_size   // true if broker limits packet size
info.maximum_packet_size       // Max packet size
info.has_session_expiry        // true if broker sent session expiry
info.session_expiry_interval   // Session Expiry Interval
info.has_assigned_client_id    // true if broker assigned client ID
info.assigned_client_id        // Assigned Client ID
```

### QoS Levels

| QoS | Flow | Reliability |
|-----|------|-------------|
| 0 | PUBLISH → done | At most once |
| 1 | PUBLISH → PUBACK | At least once (with retry) |
| 2 | PUBLISH → PUBREC → PUBREL → PUBCOMP | Exactly once |

### Topic Alias

Reduce bandwidth by replacing topic strings with numeric aliases:

```cpp
client.Publish("long/topic/name/here", "data", 0, false, 1);  // Register alias 1
client.Publish("", "data", 0, false, 1);                        // Reuse alias 1
```

### Flow Control

The client automatically enforces Receive Maximum from CONNACK:

- Tracks send quota (`receive_maximum`)
- Blocks publish when quota exhausted
- Increments quota on PUBACK/PUBCOMP receipt

### Will Message

Set a last-will message that the broker publishes if the client disconnects abnormally:

```cpp
params.will_topic  = "clients/status";
params.will_payload = "offline";
params.will_qos    = 1;
params.will_retain = false;
params.will_props.will_delay_interval = 5;  // seconds
```

Use `ForceDisconnect()` to simulate abnormal disconnect (triggers Will).
Normal `Disconnect()` tells the broker NOT to publish the Will.

## Testing

15 focused test scripts included in `Scripts/MQTTFive/`:

| Script | Coverage |
|--------|----------|
| TestT01_Connect | Connect/Disconnect + CONNACK properties |
| TestT02_Qos0Roundtrip | QoS 0 pub/sub |
| TestT03_Qos1Roundtrip | QoS 1 + PUBACK |
| TestT04_Qos2Roundtrip | QoS 2 full flow |
| TestT05_Properties | CONNECT/CONNACK properties |
| TestT06_WillMessage | Will on abnormal disconnect |
| TestT07_Keepalive | PINGREQ/PINGRESP |
| TestT08_FlowControl | Receive Maximum enforcement |
| TestT09_TopicAlias | Alias register + reuse |
| TestT10_SubscriptionOptions | No Local flag |
| TestT11_Unsubscribe | Unsubscribe verification |
| TestT12_LargePayload | 1KB + 10KB payloads |
| TestT13_Utf8Topics | Cyrillic topics and payloads |
| TestT14_BinaryPayload | Full 0x00-0xFF byte range |
| TestT15_MultiPubSub | 3 subscribers, 1 publisher |

### Running Tests

1. Start Mosquitto 5.0 on `127.0.0.1:1883`
2. Compile test scripts in MetaEditor
3. Run from MT5 Navigator → Scripts → MQTTFive

Each script prints `PASS/FAIL` per check and a summary line.

## Project Structure

```
Include/MQTTFive/
  MQTTTypes.mqh       Enums, constants, data structures
  MQTTBuffer.mqh      Byte buffer with read/write position tracking
  MQTTTransport.mqh   TCP/TLS transport over MQL5 Socket API
  MQTTCodec.mqh       Packet encoding and decoding
  MQTTClient.mqh      High-level client API

Scripts/MQTTFive/
  TestT01-T15         Focused test scripts
  MQTTFiveTest.mq5    Phase 1 integration test
  MQTTFiveTestFull.mq5  Comprehensive G1-G11 test

docs/
  mqtt5_logo.png      Logo
  TEST_PLAN.md        Test scenarios documentation
```

## Limitations

See [COMPLIANCE.md](COMPLIANCE.md) for detailed MQTT 5.0 protocol compliance.

- No AUTH (enhanced authentication)
- No auto-reconnect
- Topic Alias only for outgoing PUBLISH
- Single topic filter per SUBSCRIBE packet
- No shared subscriptions
- Unknown CONNACK properties are skipped without parsing

## License

MIT
