MQTTFive — MQTT 5.0 Client Library for MQL5
=============================================

Pure MQL5 implementation. Zero DLL dependencies. TCP + TLS via native MQL5 Socket API.

## Status

**Pre-alpha.** In active development. Not production-ready.

## Structure

```
Include/MQTTFive/
  MQTTTypes.mqh       Constants, enums, data structures
  MQTTBuffer.mqh      Byte buffer with position tracking
  MQTTTransport.mqh   TCP/TLS transport over MQL5 Socket API
  MQTTCodec.mqh       Packet encoding and decoding
  MQTTClient.mqh      High-level client API

Scripts/
  MQTTFiveTest.mq5    Integration test script

docs/
  SPEC.md             Architecture and API specification
```

## Requirements

- MetaTrader 5 terminal
- MQTT 5.0 compatible broker (Mosquitto >= 5.0, EMQX, HiveMQ)

## Quick Start

```cpp
#include <MQTTFive/MQTTClient.mqh>

MQTTClient *client;

void OnMessage(string &topic, uchar &payload[], uint payload_len)
  {
   string msg = CharArrayToString(payload, 0, (int)payload_len);
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

   if(client.Connect("127.0.0.1", 1883, params))
     {
      client.Subscribe("test/#", 0);

      while(!IsStopped())
        {
         client.Publish("test/hello", "world");
         client.Loop();
         Sleep(1000);
        }

      client.Disconnect();
     }

   delete client;
  }
```

## Installation

Copy `Include/MQTTFive/` to your MT5 `MQL5/Include/` directory.

## Features (Phase 1)

- MQTT v5.0 protocol (Protocol Version = 0x05)
- TCP + TLS via native MQL5 Socket API
- Binary-safe payload (`uchar[]`)
- UTF-8 string conversion via `CP_UTF8`
- QoS 0 publish and subscribe
- PUBACK for incoming QoS 1 messages
- Keepalive with PINGREQ/PINGRESP
- Dynamic buffer with automatic growth

## Limitations (Phase 1)

- No MQTT 5.0 Properties (Properties Length = 0)
- No QoS 2 (PUBREC/PUBREL/PUBCOMP)
- No Will messages
- No AUTH (enhanced authentication)
- No auto-reconnect
- Subscribe supports 1 topic filter per SUBSCRIBE

## Roadmap

- **Phase 2:** Properties, Will messages, Topic Alias
- **Phase 3:** QoS 1 inflight tracking, QoS 2 flow
- **Phase 4:** AUTH, auto-reconnect, shared subscriptions

## License

MIT
