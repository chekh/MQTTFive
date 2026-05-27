//+------------------------------------------------------------------+
//|                                         MQTTFiveTest.mq5         |
//|                    MQTT 5.0 Client Library — Integration Test     |
//+------------------------------------------------------------------+
#property copyright "MQTTFive"
#property link      "https://github.com/chekh/MQTTFive"
#property version   "1.00"
#property script_show_inputs

input string InpHost       = "127.0.0.1";
input int    InpPort       = 1883;
input string InpClientId   = "mql5_test";
input string InpUsername   = "";
input string InpPassword   = "";
input bool   InpTLS        = false;

#include <MQTTFive/MQTTClient.mqh>

MQTTClient *client;

void OnMessage(string &topic, uchar &payload[], uint payload_len)
  {
   string msg = CharArrayToString(payload, 0, (int)payload_len);
   Print("Received: topic=", topic, " payload=", msg);
  }

void OnStart()
  {
   client = new MQTTClient();
   client.SetLog(true);
   client.SetCallback(OnMessage);

   MQTTConnectParams params;
   params.Init();
   params.client_id = InpClientId;
   params.username = InpUsername;
   params.password = InpPassword;
   params.keep_alive = 60;

   Print("Connecting to ", InpHost, ":", InpPort);
   if(!client.Connect(InpHost, (ushort)InpPort, params, InpTLS))
     {
      Print("Connect failed: ", client.GetLastError());
      delete client;
      return;
     }
   Print("Connected!");

   client.Subscribe("mql5/test/#", 0);

   client.Publish("mql5/test/hello", "Hello from MQTTFive!");

   uchar binary[];
   ArrayResize(binary, 5);
   binary[0] = 0x00; binary[1] = 0x01; binary[2] = 0xFF;
   binary[3] = 0xFE; binary[4] = 0x80;
   client.Publish("mql5/test/binary", binary, 5);

   uchar large[];
   ArrayResize(large, 8192);
   ArrayInitialize(large, 0xAB);
   client.Publish("mql5/test/large", large, 8192);

   Print("Tests sent, entering loop...");

   int count = 0;
   while(!IsStopped() && count < 30)
     {
      string msg = StringFormat("tick %d, time %s", count, TimeToString(TimeLocal()));
      client.Publish("mql5/test/hello", msg);
      client.Loop();
      Sleep(1000);
      count++;
     }

   client.Disconnect();
   Print("Done");
   delete client;
  }
