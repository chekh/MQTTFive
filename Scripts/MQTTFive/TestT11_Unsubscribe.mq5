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

string g_last_payload = "";
bool g_received = false;
int g_total_count = 0;

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
   g_last_payload = CharArrayToString(payload, 0, (int)payload_len);
   g_received = true;
   g_total_count++;
}

void OnStart()
{
   Print("=== T11: Unsubscribe ===");

   MQTTClient clientA;
   MQTTClient clientB;

   MQTTConnectParams paramsA;
   paramsA.Init();
   paramsA.client_id = "t11_sub";
   paramsA.username = InpUsername;
   paramsA.password = InpPassword;
   paramsA.keep_alive = 60;
   paramsA.clean_start = true;

   MQTTConnectParams paramsB;
   paramsB.Init();
   paramsB.client_id = "t11_pub";
   paramsB.username = InpUsername;
   paramsB.password = InpPassword;
   paramsB.keep_alive = 60;
   paramsB.clean_start = true;

   Assert(clientA.Connect(InpHost, (ushort)InpPort, paramsA, InpTLS), "ClientA connect");
   Assert(clientB.Connect(InpHost, (ushort)InpPort, paramsB, InpTLS), "ClientB connect");

   clientA.SetCallback(OnMsgA);

   Assert(clientA.Subscribe("test/t11", 0), "ClientA subscribe test/t11");

   Sleep(100);
   clientA.Loop();

   Assert(clientB.Publish("test/t11", "before_unsub", 0), "Publish before_unsub");

   g_received = false;
   for(int i = 0; i < 50 && !g_received; i++)
     {
      Sleep(10);
      clientA.Loop();
     }

   Assert(g_received, "Received 'before_unsub'");
   Assert(g_last_payload == "before_unsub", "Payload == 'before_unsub'");

   Assert(clientA.Unsubscribe("test/t11"), "Unsubscribe test/t11");

   for(int i = 0; i < 10; i++)
     {
      Sleep(10);
      clientA.Loop();
     }

   int count_before = g_total_count;

   Assert(clientB.Publish("test/t11", "after_unsub", 0), "Publish after_unsub");

   for(int i = 0; i < 20; i++)
     {
      Sleep(50);
      clientA.Loop();
     }

   Assert(g_total_count == count_before, "Did NOT receive 'after_unsub'");

   clientA.Disconnect();
   clientB.Disconnect();

   Print("=== T11: ", g_pass, " passed, ", g_fail, " failed ===");
}
