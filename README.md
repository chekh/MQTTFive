<div align="center">
  <img src="docs/mqtt5_logo.png" alt="MQTTFive" width="200"/>
</div>

# MQTTFive — MQTT 5.0 Client for MQL5

Pure MQL5 implementation of the MQTT 5.0 protocol. Zero DLL dependencies.
TCP and TLS via native MQL5 Socket API.

## Features

- MQTT v5.0 — full protocol version 5
- QoS 0, 1, 2 with inflight tracking and retry
- CONNECT/CONNACK properties
- Will messages with properties
- Topic Alias (outgoing)
- Flow Control (Receive Maximum)
- Subscription Options (no_local, retain_as_published, retain_handling)
- DISCONNECT with reason code + session expiry
- Keepalive, binary payload, UTF-8, TLS

## Quick Start

```cpp
#include <MQTTFive/MQTTClient.mqh>

void OnMessage(string &topic, uchar &payload[], uint payload_len)
  {
   string msg = CharArrayToString(payload, 0, (int)payload_len, CP_UTF8);
   Print("Received: ", topic, " = ", msg);
  }

void OnStart()
  {
   MQTTClient client;
   client.SetCallback(OnMessage);

   MQTTConnectParams params;
   params.Init();
   params.client_id = "mql5_client";

   if(client.Connect("127.0.0.1", 1883, params))
     {
      client.Subscribe("test/#", 0);
      while(!IsStopped())
        {
         client.Loop();
         Sleep(100);
        }
      client.Disconnect();
     }
  }
```

## Documentation

| Document | Description |
|----------|-------------|
| [Installation](docs/INSTALLATION.md) | How to install in MT5, verify, troubleshoot |
| [Getting Started](docs/GETTING_STARTED.md) | Examples: publisher, subscriber, EA, binary, TLS |
| [API Reference](docs/API_REFERENCE.md) | Full method and data structure reference |
| [Architecture](docs/ARCHITECTURE.md) | Library layers, source code overview, event loop |
| [Compliance](COMPLIANCE.md) | MQTT 5.0 protocol compliance, simplifications, limitations |

## Requirements

- MetaTrader 5 (build 3390+)
- MQTT 5.0 broker (Mosquitto >= 5.0, EMQX, HiveMQ)

## License

MIT
