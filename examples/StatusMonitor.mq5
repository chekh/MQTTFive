//+------------------------------------------------------------------+
//|                                       StatusMonitor.mq5           |
//|                                  MQTTFive example                 |
//|              EA that publishes connection status and account info  |
//+------------------------------------------------------------------+
#property copyright "MQTTFive"
#property link      "https://github.com/chekh/MQTTFive"
#property version   "1.00"
#property strict

#include <MQTTFive/MQTTClient.mqh>

input string InpHost       = "127.0.0.1";
input int    InpPort       = 1883;
input string InpClientId   = "mt5_monitor";
input int    InpPublishSec = 5;

MQTTClient *mqtt;
datetime g_last_publish = 0;

void PublishStatus()
  {
   string status_topic = "mt5/status/" + InpClientId;

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin     = AccountInfoDouble(ACCOUNT_MARGIN);
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   int    positions  = PositionsTotal();
   int    orders     = OrdersTotal();

   string payload = StringFormat(
      "{\"balance\":%.2f,\"equity\":%.2f,\"margin\":%.2f,\"free\":%.2f,\"positions\":%d,\"orders\":%d}",
      balance, equity, margin, free_margin, positions, orders);

   mqtt.Publish(status_topic, payload, 0, true);

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      string pos_topic = StringFormat("mt5/position/%s/%d",
                                       PositionGetString(POSITION_SYMBOL), ticket);

      string pos_payload = StringFormat(
         "{\"symbol\":\"%s\",\"type\":\"%s\",\"lots\":%.2f,\"open_price\":%.5f,\"sl\":%.5f,\"tp\":%.5f,\"profit\":%.2f}",
         PositionGetString(POSITION_SYMBOL),
         (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL",
         PositionGetDouble(POSITION_VOLUME),
         PositionGetDouble(POSITION_PRICE_OPEN),
         PositionGetDouble(POSITION_SL),
         PositionGetDouble(POSITION_TP),
         PositionGetDouble(POSITION_PROFIT));

      mqtt.Publish(pos_topic, pos_payload, 0);
     }
  }

int OnInit()
  {
   mqtt = new MQTTClient();

   MQTTConnectParams params;
   params.Init();
   params.client_id = InpClientId;
   params.keep_alive = 30;
   params.clean_start = true;
   params.will_topic   = "mt5/status/" + InpClientId;
   params.will_payload  = "{\"status\":\"offline\"}";
   params.will_qos     = 1;
   params.will_retain  = true;

   if(!mqtt.Connect(InpHost, (ushort)InpPort, params))
     {
      Print("MQTT connect failed: ", mqtt.GetLastError());
      return INIT_FAILED;
     }

   mqtt.Publish("mt5/status/" + InpClientId,
                "{\"status\":\"online\"}", 0, true);

   EventSetTimer(InpPublishSec);
   Print("StatusMonitor started, publishing every ", InpPublishSec, "s");
   return INIT_SUCCEEDED;
  }

void OnTimer()
  {
   if(!mqtt.IsConnected())
     {
      Print("MQTT disconnected");
      return;
     }
   mqtt.Loop();
   PublishStatus();
  }

void OnTick()
  {
   mqtt.Loop();
  }

void OnDeinit(const int reason)
  {
   if(mqtt != NULL)
     {
      if(mqtt.IsConnected())
        {
         mqtt.Publish("mt5/status/" + InpClientId,
                      "{\"status\":\"offline\"}", 0, true);
         mqtt.Disconnect();
        }
      delete mqtt;
      mqtt = NULL;
     }
   EventKillTimer();
   Print("StatusMonitor stopped");
  }
