#property copyright "MQTTFive"
#property link      "https://github.com/chekh/MQTTFive"
#property version   "1.00"
#property script_show_inputs

#include <MQTTFive/MQTTClient.mqh>

input string InpHost       = "127.0.0.1";
input int    InpPort       = 1883;
input string InpUsername   = "";
input string InpPassword   = "";
input bool   InpTLS        = false;

int g_pass = 0;
int g_fail = 0;

bool g_received = false;
string g_rx_topic = "";
string g_rx_payload = "";

void Assert(bool condition, string msg)
{
   if(condition)
     {
      g_pass++;
      Print("  PASS: ", msg);
     }
   else
     {
      g_fail++;
      Print("  FAIL: ", msg);
     }
}

void OnMsgA(string &topic, uchar &payload[], uint payload_len)
{
   g_rx_topic = topic;
    g_rx_payload = CharArrayToString(payload, 0, (int)payload_len, CP_UTF8);
   g_received = true;
}

void OnStart()
{
   Print("=== T13: UTF-8 Topics ===");

   MQTTClient clientA;
   MQTTClient clientB;

   MQTTConnectParams paramsA;
   paramsA.Init();
   paramsA.client_id = "t13_sub";
   paramsA.username = InpUsername;
   paramsA.password = InpPassword;
   paramsA.keep_alive = 60;
   paramsA.clean_start = true;

   MQTTConnectParams paramsB;
   paramsB.Init();
   paramsB.client_id = "t13_pub";
   paramsB.username = InpUsername;
   paramsB.password = InpPassword;
   paramsB.keep_alive = 60;
   paramsB.clean_start = true;

   Assert(clientA.Connect(InpHost, (ushort)InpPort, paramsA, InpTLS), "ClientA connect");
   Assert(clientB.Connect(InpHost, (ushort)InpPort, paramsB, InpTLS), "ClientB connect");

   clientA.SetCallback(OnMsgA);

   Assert(clientA.Subscribe("тест/t13/топика", 0), "Subscribe UTF-8 topic");

   Sleep(100);
   clientA.Loop();

   Assert(clientB.Publish("тест/t13/топика", "Привет MQTTFive!", 0), "Publish UTF-8 topic + payload");

   for(int i = 0; i < 50 && !g_received; i++)
     {
      Sleep(10);
      clientA.Loop();
     }

   Assert(g_received, "Received UTF-8 message");
   Assert(g_rx_topic == "тест/t13/топика", "Topic matches UTF-8");
   Assert(g_rx_payload == "Привет MQTTFive!", "Payload matches UTF-8");

   clientA.Disconnect();
   clientB.Disconnect();

   Print("=== T13: ", g_pass, " passed, ", g_fail, " failed ===");
}
