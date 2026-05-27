//+------------------------------------------------------------------+
//|                                         PricePublisher.mq5        |
//|                                  MQTTFive example                 |
//|                        Publishes bid/ask prices to MQTT           |
//+------------------------------------------------------------------+
#property copyright "MQTTFive"
#property link      "https://github.com/chekh/MQTTFive"
#property version   "1.00"
#property script_show_inputs

#include <MQTTFive/MQTTClient.mqh>

input string InpHost       = "127.0.0.1";
input int    InpPort       = 1883;
input string InpClientId   = "mt5_price_pub";
input string InpTopic      = "mt5/price";
input int    InpIntervalMs = 1000;
input int    InpQoS        = 0;

MQTTClient *mqtt;

void OnStart()
  {
   mqtt = new MQTTClient();

   MQTTConnectParams params;
   params.Init();
   params.client_id = InpClientId;
   params.keep_alive = 60;
   params.clean_start = true;

   if(!mqtt.Connect(InpHost, (ushort)InpPort, params))
     {
      Print("Connect failed: ", mqtt.GetLastError());
      delete mqtt;
      return;
     }

   Print("Connected, publishing ", _Symbol, " prices to ", InpTopic);

   while(!IsStopped())
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      string payload = StringFormat("{\"symbol\":\"%s\",\"bid\":%.5f,\"ask\":%.5f,\"time\":\"%s\"}",
                                     _Symbol, bid, ask,
                                     TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));

      if(!mqtt.Publish(InpTopic, payload, (uchar)InpQoS))
         Print("Publish failed: ", mqtt.GetLastError());

      mqtt.Loop();
      Sleep(InpIntervalMs);
     }

   mqtt.Disconnect();
   delete mqtt;
   Print("Disconnected");
  }
