//+------------------------------------------------------------------+
//|                                     TradeSignalReceiver.mq5       |
//|                                  MQTTFive example                 |
//|                     Receives trade signals via MQTT and logs them  |
//+------------------------------------------------------------------+
#property copyright "MQTTFive"
#property link      "https://github.com/chekh/MQTTFive"
#property version   "1.00"
#property script_show_inputs

#include <MQTTFive/MQTTClient.mqh>

input string InpHost       = "127.0.0.1";
input int    InpPort       = 1883;
input string InpClientId   = "mt5_signal_sub";
input string InpTopic      = "trade/signal/#";

MQTTClient *mqtt;
int g_signals = 0;

void OnSignal(string &topic, uchar &payload[], uint payload_len)
  {
   string msg = CharArrayToString(payload, 0, (int)payload_len, CP_UTF8);
   g_signals++;
   PrintFormat("[signal #%d] %s: %s", g_signals, topic, msg);

   if(StringFind(topic, "buy") >= 0)
      Print("  >>> BUY signal received");
   else if(StringFind(topic, "sell") >= 0)
      Print("  >>> SELL signal received");
  }

void OnStart()
  {
   mqtt = new MQTTClient();
   mqtt.SetCallback(OnSignal);

   MQTTConnectParams params;
   params.Init();
   params.client_id = InpClientId;
   params.keep_alive = 60;
   params.clean_start = true;
   params.will_topic   = "mt5/status/" + InpClientId;
   params.will_payload  = "offline";
   params.will_qos     = 1;

   if(!mqtt.Connect(InpHost, (ushort)InpPort, params))
     {
      Print("Connect failed: ", mqtt.GetLastError());
      delete mqtt;
      return;
     }

   if(!mqtt.Subscribe(InpTopic, 1))
     {
      Print("Subscribe failed");
      mqtt.Disconnect();
      delete mqtt;
      return;
     }

   Print("Listening on ", InpTopic, " (Ctrl+C to stop)");

   while(!IsStopped())
     {
      mqtt.Loop();
      Sleep(100);
     }

   mqtt.Publish("mt5/status/" + InpClientId, "offline", 0, true);
   mqtt.Disconnect();
   delete mqtt;
   PrintFormat("Stopped. Received %d signals total.", g_signals);
  }
