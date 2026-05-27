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

string g_msgs[10];
int g_msg_count = 0;

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
      g_msgs[g_msg_count] = CharArrayToString(payload, 0, (int)payload_len);
     }
   g_msg_count++;
}

void OnStart()
{
   Print("=== T10: Subscription Options ===");

   MQTTClient clientA;
   MQTTClient clientB;

   MQTTConnectParams paramsA;
   paramsA.Init();
   paramsA.client_id = "t10_a";
   paramsA.username = InpUsername;
   paramsA.password = InpPassword;
   paramsA.keep_alive = 60;
   paramsA.clean_start = true;

   MQTTConnectParams paramsB;
   paramsB.Init();
   paramsB.client_id = "t10_b";
   paramsB.username = InpUsername;
   paramsB.password = InpPassword;
   paramsB.keep_alive = 60;
   paramsB.clean_start = true;

   Assert(clientA.Connect(InpHost, (ushort)InpPort, paramsA, InpTLS), "ClientA connect");
   Assert(clientB.Connect(InpHost, (ushort)InpPort, paramsB, InpTLS), "ClientB connect");

   clientA.SetCallback(OnMsgA);

   MQTTSubscribeParams subParams;
   subParams.Init();
   subParams.topic_filter = "test/t10";
   subParams.options.no_local = true;
   subParams.options.maximum_qos = 0;

   Assert(clientA.Subscribe(subParams), "Subscribe test/t10 with no_local=true");

   Sleep(100);
   clientA.Loop();

   Assert(clientA.Publish("test/t10", "self_msg", 0), "ClientA publish to self");

   Sleep(100);
   for(int i = 0; i < 10; i++)
     {
      clientA.Loop();
      Sleep(10);
     }

   Assert(clientB.Publish("test/t10", "other_msg", 0), "ClientB publish to test/t10");

   for(int i = 0; i < 20; i++)
     {
      Sleep(50);
      clientA.Loop();
     }

   Assert(g_msg_count >= 1, "Received at least 1 message");

   bool found_other = false;
   bool found_self = false;
   for(int i = 0; i < g_msg_count && i < 10; i++)
     {
      if(g_msgs[i] == "other_msg") found_other = true;
      if(g_msgs[i] == "self_msg") found_self = true;
     }

   Assert(found_other, "Received 'other_msg' from ClientB");
   Assert(!found_self, "Did NOT receive 'self_msg' (no_local=true)");

   clientA.Disconnect();
   clientB.Disconnect();

   Print("=== T10: ", g_pass, " passed, ", g_fail, " failed ===");
}
