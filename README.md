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

### Option 1: Copy files manually

1. Find your MT5 data directory: open MT5 → File → Open Data Folder
2. Copy `Include/MQTTFive/` folder to `MQL5/Include/MQTTFive/`
3. Result: `MQL5/Include/MQTTFive/MQTTClient.mqh`, `MQTTCodec.mqh`, etc.
4. In MetaEditor, your code can now use `#include <MQTTFive/MQTTClient.mqh>`

### Option 2: Clone into Include directory

```bash
cd <MT5_DATA>/MQL5/Include/
git clone https://github.com/chekh/MQTTFive.git MQTTFive
```

### Option 3: Symlink (for development)

```bash
cd <MT5_DATA>/MQL5/Include/
ln -s /path/to/MQTTFive/Include/MQTTFive MQTTFive
```

### Test scripts (optional)

Copy `Scripts/MQTTFive/` to `MQL5/Scripts/MQTTFive/`. They appear in
MT5 Navigator under Scripts → MQTTFive.

### Verify installation

Create a test script in MetaEditor:

```cpp
#property script_show_inputs
#include <MQTTFive/MQTTClient.mqh>

void OnStart()
  {
   MQTTClient client;
   MQTTConnectParams params;
   params.Init();
   params.client_id = "install_test";
   if(client.Connect("127.0.0.1", 1883, params))
      Print("OK: connected");
   else
      Print("FAIL: ", client.GetLastError());
   client.Disconnect();
  }
```

Compile and run. You should see `OK: connected` if Mosquitto is running.

## Quick Start

### Minimal publisher

```cpp
#include <MQTTFive/MQTTClient.mqh>

void OnStart()
  {
   MQTTClient client;

   MQTTConnectParams params;
   params.Init();
   params.client_id = "my_publisher";

   if(client.Connect("127.0.0.1", 1883, params))
     {
      client.Publish("test/hello", "world", 0);
      Print("Published");
      client.Disconnect();
     }
   else
      Print("Error: ", client.GetLastError());
  }
```

### Subscriber with callback

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
   params.client_id = "mql5_subscriber";
   params.keep_alive = 60;
   params.clean_start = true;

   if(client.Connect("127.0.0.1", 1883, params))
     {
      client.Subscribe("sensors/#", 0);

      while(!IsStopped())
        {
         client.Loop();
         Sleep(100);
        }

      client.Disconnect();
     }

   delete client;
  }
```

### Using in an Expert Advisor (EA)

MQTTFive works in EAs the same way as scripts. Use `OnTick()` or `OnTimer()`
to call `Loop()` regularly:

```cpp
#include <MQTTFive/MQTTClient.mqh>

MQTTClient *mqtt;

void OnMessage(string &topic, uchar &payload[], uint payload_len)
  {
   if(topic == "trade/signal")
     {
      string signal = CharArrayToString(payload, 0, (int)payload_len, CP_UTF8);
      Print("Signal: ", signal);
     }
  }

int OnInit()
  {
   mqtt = new MQTTClient();
   mqtt.SetCallback(OnMessage);

   MQTTConnectParams params;
   params.Init();
   params.client_id = "ea_client";
   params.keep_alive = 60;

   if(!mqtt.Connect("127.0.0.1", 1883, params))
     {
      Print("MQTT connect failed: ", mqtt.GetLastError());
      return INIT_FAILED;
     }

   mqtt.Subscribe("trade/#", 1);
   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnTimer()
  {
   mqtt.Loop();
  }

void OnTick()
  {
   mqtt.Loop();
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string payload = DoubleToString(price, _Digits);
   mqtt.Publish("market/" + _Symbol, payload, 0);
  }

void OnDeinit(const int reason)
  {
   if(mqtt != NULL)
     {
      mqtt.Disconnect();
      delete mqtt;
      mqtt = NULL;
     }
   EventKillTimer();
  }
```

### Important: Stack vs Heap allocation

MQL5 classes can be allocated on stack or heap:

```cpp
// Stack allocation (destroyed when variable goes out of scope)
MQTTClient client;
client.Connect(host, port, params);

// Heap allocation (destroyed by delete)
MQTTClient *client = new MQTTClient();
client.Connect(host, port, params);
delete client;
```

Both work. Use heap (`new`) when the client needs to live across function calls
(e.g., global in an EA). Use stack for simple scripts.

### Binary payloads

Use `uchar[]` overload for binary data:

```cpp
uchar data[];
ArrayResize(data, 4);
data[0] = 0x01;
data[1] = 0x02;
data[2] = 0x03;
data[3] = 0x04;
client.Publish("binary/topic", data, 4, 0);
```

On the receiving end, payload comes as `uchar[]` — decode as needed:

```cpp
void OnMessage(string &topic, uchar &payload[], uint payload_len)
  {
   // As string (UTF-8):
   string text = CharArrayToString(payload, 0, (int)payload_len, CP_UTF8);

   // As raw bytes:
   for(int i = 0; i < (int)payload_len; i++)
      PrintFormat("payload[%d] = 0x%02X", i, payload[i]);
  }
```

### TLS (SSL/TLS) connections

Pass `true` as the 4th argument to `Connect()`:

```cpp
params.client_id = "secure_client";
client.Connect("broker.example.com", 8883, params, true);
```

Uses MQL5's built-in `SocketTlsHandshake`. The broker must have a valid
certificate (or be added to the trusted certificates list).

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

## Architecture

The library is organized in four layers:

```
MQTTClient.mqh        ← User-facing API (publish, subscribe, loop)
    |
MQTTCodec.mqh         ← Packet encode/decode (MQTT wire format)
    |
MQTTBuffer.mqh        ← Binary buffer with position tracking
    |
MQTTTransport.mqh     ← TCP/TLS via MQL5 Socket API
```

### MQTTTypes.mqh

All shared types and constants. You only need this file if you access
`MQTTConnectParams`, `MQTTConnackInfo`, `MQTTSubscribeParams`, or
`MQTTSubscriptionOptions` directly. Included automatically by `MQTTClient.mqh`.

Key types:
- `MQTTConnectParams` — connection parameters (client ID, credentials, will, properties)
- `MQTTConnackInfo` — broker response (capabilities, limits)
- `MQTTSubscribeParams` — subscription with options
- `MQTTSubscriptionOptions` — QoS, no_local, retain_as_published, retain_handling
- `MQTTPublishMessage` — incoming message (topic, payload, QoS, retain, dup)
- `MQTTWillProperties` — will delay, payload format, message expiry, content type

### MQTTBuffer.mqh

Internal byte buffer with separate read/write positions. Used by codec for
encoding packets to bytes and decoding bytes back to structured data.

Not used directly by application code.

### MQTTTransport.mqh

Thin wrapper over MQL5 Socket API (`SocketCreate`, `SocketConnect`,
`SocketSend`, `SocketRead`, `SocketTlsHandshake`). Handles TCP and TLS.

Not used directly by application code.

### MQTTCodec.mqh

Static methods for encoding and decoding all MQTT packet types. Translates
between structured data (params, message structs) and wire format bytes.

Not used directly by application code — called internally by `MQTTClient`.

### MQTTClient.mqh

The only class you need. Provides:

- **Connect/Disconnect** — manages connection lifecycle
- **Publish** — sends messages (string or binary payload)
- **Subscribe/Unsubscribe** — manages topic subscriptions
- **Loop** — must be called regularly to:
  - Process incoming packets (PUBLISH, PUBACK, PUBREC, PUBREL, etc.)
  - Send keepalive PINGREQ when idle
  - Retry unacknowledged QoS 1/2 messages
- **GetConnackInfo** — broker capabilities after connect
- **SetCallback** — function called when a subscribed message arrives

### Event loop pattern

MQTTFive is single-threaded (MQL5 limitation). The `Loop()` method must be
called regularly. It processes at most **one** incoming packet per call.
For QoS 1 and 2, call `Loop()` frequently (every 50-100ms) to ensure
timely ACK processing.

```
while(!IsStopped())
  {
   mqtt.Loop();     // process ONE incoming packet + keepalive + retry
   Sleep(100);      // yield to MT5
  }
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
