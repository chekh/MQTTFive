# Getting Started

## Minimal publisher

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

## Subscriber with callback

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

## Using in an Expert Advisor (EA)

MQTTFive works in EAs. Call `Loop()` from `OnTick()` or `OnTimer()`:

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

## Stack vs Heap allocation

MQL5 supports both:

```cpp
// Stack — destroyed when variable goes out of scope
MQTTClient client;
client.Connect(host, port, params);

// Heap — destroyed by delete
MQTTClient *client = new MQTTClient();
client.Connect(host, port, params);
delete client;
```

Use heap (`new`) when the client needs to live across function calls (e.g.,
global pointer in an EA). Use stack for simple scripts.

## Binary payloads

```cpp
// Sending binary data
uchar data[];
ArrayResize(data, 4);
data[0] = 0x01; data[1] = 0x02; data[2] = 0x03; data[3] = 0x04;
client.Publish("binary/topic", data, 4, 0);

// Receiving binary data
void OnMessage(string &topic, uchar &payload[], uint payload_len)
  {
   // As UTF-8 string:
   string text = CharArrayToString(payload, 0, (int)payload_len, CP_UTF8);

   // As raw bytes:
   for(int i = 0; i < (int)payload_len; i++)
      PrintFormat("payload[%d] = 0x%02X", i, payload[i]);
  }
```

## TLS (SSL/TLS)

Pass `true` as the 4th argument:

```cpp
params.client_id = "secure_client";
client.Connect("broker.example.com", 8883, params, true);
```

Uses MQL5's built-in `SocketTlsHandshake`. The broker must have a valid
certificate or be in the trusted certificates list.

## Will message

The broker publishes the Will message if the client disconnects abnormally:

```cpp
params.will_topic   = "clients/status";
params.will_payload  = "offline";
params.will_qos     = 1;
params.will_retain  = false;
params.will_props.will_delay_interval = 5;
```

Important:
- `Disconnect()` — normal disconnect, broker does NOT publish Will
- `ForceDisconnect()` — TCP close without DISCONNECT, broker publishes Will

## Topic Alias

Reduce bandwidth on repetitive topics:

```cpp
// Register alias 1 with a topic
client.Publish("long/topic/name/here", "data", 0, false, 1);

// Reuse alias 1 (empty topic string)
client.Publish("", "data", 0, false, 1);
```

The alias mapping is stored on the broker. Maximum alias value is limited by
`CONNACK topic_alias_maximum` (checked automatically).

## QoS levels

```cpp
client.Publish("topic", "fire-and-forget", 0);  // QoS 0 — at most once
client.Publish("topic", "important", 1);          // QoS 1 — at least once
client.Publish("topic", "critical", 2);           // QoS 2 — exactly once
```

For QoS 1 and 2, call `Loop()` frequently to process acknowledgments and
retries. If PUBACK/PUBREC is not received within `m_retry_timeout` (default
20 seconds), the message is resent automatically.

## Multiple clients

You can create multiple `MQTTClient` instances in the same script or EA:

```cpp
MQTTClient clientA;
MQTTClient clientB;

MQTTConnectParams paramsA, paramsB;
paramsA.Init(); paramsA.client_id = "client_a";
paramsB.Init(); paramsB.client_id = "client_b";

clientA.Connect("127.0.0.1", 1883, paramsA);
clientB.Connect("127.0.0.1", 1883, paramsB);

// Each client has independent connection and subscriptions
clientA.Subscribe("topic/a", 0);
clientB.Subscribe("topic/b", 0);

while(!IsStopped())
  {
   clientA.Loop();
   clientB.Loop();
   Sleep(100);
  }

clientA.Disconnect();
clientB.Disconnect();
```

Each client must have a unique `client_id`.
