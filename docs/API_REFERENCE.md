# API Reference

## MQTTClient

### Connection

#### `bool Connect(string host, ushort port, MQTTConnectParams &params, bool useTLS = false, uint timeout = 15)`

Connect to MQTT broker. Blocks until CONNACK received or timeout.

- `host` — broker hostname or IP address
- `port` — broker port (1883 for TCP, 8883 for TLS)
- `params` — connection parameters (see below)
- `useTLS` — enable TLS/SSL
- `timeout` — connection timeout in seconds

Returns `true` on success. On failure, check `GetLastError()`.

#### `bool Disconnect()`

Send MQTT DISCONNECT packet and close TCP connection. The broker will NOT
publish the Will message on normal disconnect.

#### `bool Disconnect(uchar reason_code, uint session_expiry = 0)`

Send DISCONNECT with MQTT 5.0 reason code and optional session expiry interval.

Common reason codes:
- `0x00` — Normal disconnection
- `0x04` — Disconnect with Will Message
- `0x00`–`0x80` — see MQTT 5.0 spec §3.14.2

#### `void ForceDisconnect()`

Close TCP connection without sending DISCONNECT packet. The broker interprets
this as an abnormal disconnect and publishes the Will message (if configured).

#### `bool IsConnected()`

Returns `true` if the client is in connected state.

#### `bool Loop()`

Process one incoming packet, check keepalive, retry unacknowledged messages.
Must be called regularly (every 50–1000ms) from your main loop.

Returns `false` if the connection was lost or an error occurred.

#### `MQTTConnackInfo GetConnackInfo()`

Returns parsed CONNACK properties from the broker. Available after `Connect()`
succeeds. See MQTTConnackInfo structure below.

#### `string GetLastError()`

Returns human-readable description of the last error.

#### `int GetLastErrorCode()`

Returns numeric error code of the last error.

### Publishing

#### `bool Publish(string topic, string payload, uchar qos = 0, bool retain = false)`

Publish a UTF-8 string payload.

- `topic` — topic name (must not be empty, unless using Topic Alias)
- `payload` — string payload (converted to UTF-8 via `CP_UTF8`)
- `qos` — 0, 1, or 2
- `retain` — broker stores the message as last-known-good

Returns `true` if the packet was sent. For QoS 0, this means "sent to socket".
For QoS 1/2, delivery confirmation comes through `Loop()`.

#### `bool Publish(string topic, uchar &payload[], uint payload_len, uchar qos = 0, bool retain = false)`

Publish a binary `uchar[]` payload. Use this for non-text data or when you need
full control over payload bytes.

#### `bool Publish(string topic, string payload, uchar qos, bool retain, ushort topic_alias)`

Publish with Topic Alias. When `topic_alias > 0`:
- If `topic` is not empty: broker registers the alias → topic mapping
- If `topic` is empty: broker reuses the previously registered mapping

### Subscribing

#### `bool Subscribe(string topic, uchar qos = 0)`

Subscribe to a topic filter with a maximum QoS level.

- `topic` — topic filter (may contain wildcards `+` and `#`)
- `qos` — maximum QoS the broker should use for delivering messages

Returns `true` if the SUBSCRIBE packet was sent. SUBACK is processed in `Loop()`.

#### `bool Subscribe(MQTTSubscribeParams &params)`

Subscribe with full MQTT 5.0 subscription options (no_local, retain_as_published,
retain_handling). See MQTTSubscribeParams structure below.

#### `bool Unsubscribe(string topic)`

Unsubscribe from a topic filter. Returns `true` if UNSUBSCRIBE packet was sent.

### Configuration

#### `void SetCallback(MQTTMessageCallback callback)`

Set the function called when a subscribed message arrives. Signature:

```cpp
typedef void (*MQTTMessageCallback)(string &topic, uchar &payload[], uint payload_len);
```

Pass `NULL` to remove the callback.

#### `void SetKeepAlive(ushort seconds)`

Override the keepalive interval. Default is 60 seconds. The client sends
PINGREQ when no data has been sent for `keep_alive` seconds. If no response
within 1.5x keepalive, the connection is considered lost.

#### `void SetLog(bool enable)`

Enable debug logging to MT5 Experts log. Prints all sent/received packets.

---

## Data Structures

### MQTTConnectParams

All parameters for the CONNECT packet. Call `Init()` to set defaults before
assigning values.

```cpp
MQTTConnectParams params;
params.Init();

// Required
params.client_id    = "my_client";    // Unique client identifier

// Authentication
params.username     = "user";         // Optional
params.password     = "pass";         // Optional

// Connection behavior
params.keep_alive   = 60;             // Seconds (default: 60)
params.clean_start  = true;           // Start fresh session (default: true)

// MQTT 5.0 CONNECT Properties
params.session_expiry_interval = 0;   // 0 = session ends on disconnect
params.receive_maximum    = 65535;    // Max QoS > 0 messages in flight
params.maximum_packet_size = 0;       // 0 = no limit
params.topic_alias_maximum = 0;       // 0 = no aliases

// Will message (optional)
params.will_topic    = "status";      // Topic for will message
params.will_payload  = "offline";     // Will payload string
params.will_qos      = 0;             // QoS for will
params.will_retain   = false;         // Retain will message

// Will properties (optional)
params.will_props.will_delay_interval      = 0;   // Seconds
params.will_props.payload_format_indicator = 0;   // 0=bytes, 1=UTF-8
params.will_props.message_expiry_interval  = 0;   // Seconds
params.will_props.content_type             = "";  // MIME type
```

### MQTTConnackInfo

Parsed from the broker's CONNACK response. Access via `client.GetConnackInfo()`.

```cpp
MQTTConnackInfo info = client.GetConnackInfo();

// Always available
info.reason_code      // 0x00 = success
info.session_present  // true = broker has session state

// Conditional (check has_* before using)
info.has_receive_maximum      // Broker sent Receive Maximum
info.receive_maximum          // Max inflight QoS > 0 messages

info.has_maximum_qos          // Broker sent Maximum QoS
info.maximum_qos              // Max QoS broker supports (0, 1, or 2)

info.has_retain_available     // Broker sent Retain Available
info.retain_available         // Broker supports RETAIN

info.has_topic_alias_maximum  // Broker sent Topic Alias Maximum
info.topic_alias_maximum      // Max alias value

info.has_server_keep_alive    // Broker overrode keepalive
info.server_keep_alive        // Broker's keepalive in seconds

info.has_maximum_packet_size  // Broker limits packet size
info.maximum_packet_size      // Max packet size in bytes

info.has_session_expiry       // Broker sent session expiry
info.session_expiry_interval  // Session Expiry Interval

info.has_assigned_client_id   // Broker assigned a client ID
info.assigned_client_id       // The assigned ID string
```

Default values when `has_*` is false:
- `receive_maximum` = 65535
- `maximum_qos` = 2
- `retain_available` = true
- `topic_alias_maximum` = 0
- `server_keep_alive` = 0
- `maximum_packet_size` = 0
- `session_expiry_interval` = 0
- `assigned_client_id` = ""

### MQTTSubscribeParams

```cpp
MQTTSubscribeParams params;
params.Init();
params.topic_filter = "sensors/#";
params.options.maximum_qos        = 2;     // QoS 0, 1, or 2
params.options.no_local           = false; // Don't receive own messages
params.options.retain_as_published = false; // Keep original retain flag
params.options.retain_handling    = 0;     // 0=send retained, 1=if new, 2=never
```

### MQTTSubscriptionOptions

| Field | Values | Description |
|-------|--------|-------------|
| `maximum_qos` | 0, 1, 2 | Maximum QoS for this subscription |
| `no_local` | true/false | Don't receive messages published by this client |
| `retain_as_published` | true/false | Keep retain flag as published |
| `retain_handling` | 0, 1, 2 | 0=send retained messages, 1=only on new subscription, 2=never send |

### MQTTWillProperties

```cpp
params.will_props.Init();
params.will_props.will_delay_interval      = 5;    // Delay before publishing (seconds)
params.will_props.payload_format_indicator = 1;    // 0=bytes, 1=UTF-8
params.will_props.message_expiry_interval  = 3600; // Will message expires after (seconds)
params.will_props.content_type             = "text/plain"; // MIME type
```

### MQTTPublishMessage

Used internally by the callback. Not accessed directly by user code.

```cpp
struct MQTTPublishMessage
  {
   string topic;         // Topic name
   uchar  payload[];     // Raw payload bytes
   uint   payload_len;   // Payload length
   uchar  qos;           // 0, 1, or 2
   bool   retain;        // Retain flag
   bool   dup;           // Duplicate delivery flag
   ushort packet_id;     // Packet ID (QoS > 0)
  };
```

---

## Callback

The message callback receives all subscribed messages:

```cpp
void OnMessage(string &topic, uchar &payload[], uint payload_len)
  {
   // Convert to string (UTF-8)
   string text = CharArrayToString(payload, 0, (int)payload_len, CP_UTF8);
   Print(topic, ": ", text);
  }

client.SetCallback(OnMessage);
```

Important:
- The callback is called from within `Loop()`. Do not call `Loop()` from the callback.
- The `payload[]` array is valid only during the callback. Copy it if needed later.
- Use `CP_UTF8` in `CharArrayToString` for correct non-ASCII text handling.
