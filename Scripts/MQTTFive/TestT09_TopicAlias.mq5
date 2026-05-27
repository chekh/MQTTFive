#property copyright "MQTTFive"
#property link      "https://github.com/chekh/MQTTFive"
#property version   "1.00"
#property script_show_inputs

#include <MQTTFive/MQTTClient.mqh>

input string InpHost       = "localhost";
input int    InpPort       = 1883;
input string InpUsername   = "";
input string InpPassword   = "";
input bool   InpTLS        = false;

int g_pass = 0;
int g_fail = 0;

int g_msg_count = 0;
string g_topics[10];

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
   if(g_msg_count < 10)
     {
      g_topics[g_msg_count] = topic;
     }
   g_msg_count++;
}

void OnStart()
{
   Print("=== T09: Topic Alias ===");

   MQTTClient clientA;
   MQTTClient clientB;

   MQTTConnectParams paramsA;
   paramsA.Init();
   paramsA.client_id = "t09_sub";
   paramsA.username = InpUsername;
   paramsA.password = InpPassword;
   paramsA.keep_alive = 60;
   paramsA.clean_start = true;

   MQTTConnectParams paramsB;
   paramsB.Init();
   paramsB.client_id = "t09_pub";
   paramsB.username = InpUsername;
   paramsB.password = InpPassword;
   paramsB.keep_alive = 60;
   paramsB.clean_start = true;
   paramsB.topic_alias_maximum = 5;

   Assert(clientA.Connect(InpHost, (ushort)InpPort, paramsA, InpTLS), "ClientA connect");
   Assert(clientB.Connect(InpHost, (ushort)InpPort, paramsB, InpTLS), "ClientB connect");

   clientA.SetCallback(OnMsgA);

   Assert(clientA.Subscribe("test/t09/#", 0), "ClientA subscribe test/t09/#");

   Sleep(100);
   clientA.Loop();

   Assert(clientB.Publish("test/t09/alias", "alias_reg", 0, false, 1), "Publish with topic_alias=1 (register)");
   Assert(clientB.Publish("", "alias_reuse", 0, false, 1), "Publish empty topic with topic_alias=1 (reuse)");

   for(int i = 0; i < 20; i++)
     {
      Sleep(50);
      clientA.Loop();
     }

   Assert(g_msg_count >= 2, "Received at least 2 messages");
   Assert(g_topics[0] == "test/t09/alias", "First message topic == test/t09/alias");
   Assert(g_topics[1] == "test/t09/alias", "Second message topic == test/t09/alias (resolved from alias)");

   clientA.Disconnect();
   clientB.Disconnect();

   Print("=== T09: ", g_pass, " passed, ", g_fail, " failed ===");
}
