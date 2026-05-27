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

bool g_received_a1 = false;
string g_payload_a1 = "";
bool g_received_a2 = false;
string g_payload_a2 = "";
bool g_received_a3 = false;
string g_payload_a3 = "";

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

void OnMsgA1(string &topic, uchar &payload[], uint payload_len)
{
   g_payload_a1 = CharArrayToString(payload, 0, (int)payload_len);
   g_received_a1 = true;
}

void OnMsgA2(string &topic, uchar &payload[], uint payload_len)
{
   g_payload_a2 = CharArrayToString(payload, 0, (int)payload_len);
   g_received_a2 = true;
}

void OnMsgA3(string &topic, uchar &payload[], uint payload_len)
{
   g_payload_a3 = CharArrayToString(payload, 0, (int)payload_len);
   g_received_a3 = true;
}

void OnStart()
{
   Print("=== T15: Multi Pub/Sub ===");

   MQTTClient clientA1;
   MQTTClient clientA2;
   MQTTClient clientA3;
   MQTTClient clientB;

   MQTTConnectParams paramsA1;
   paramsA1.Init();
   paramsA1.client_id = "t15_a1";
   paramsA1.username = InpUsername;
   paramsA1.password = InpPassword;
   paramsA1.keep_alive = 60;
   paramsA1.clean_start = true;

   MQTTConnectParams paramsA2;
   paramsA2.Init();
   paramsA2.client_id = "t15_a2";
   paramsA2.username = InpUsername;
   paramsA2.password = InpPassword;
   paramsA2.keep_alive = 60;
   paramsA2.clean_start = true;

   MQTTConnectParams paramsA3;
   paramsA3.Init();
   paramsA3.client_id = "t15_a3";
   paramsA3.username = InpUsername;
   paramsA3.password = InpPassword;
   paramsA3.keep_alive = 60;
   paramsA3.clean_start = true;

   MQTTConnectParams paramsB;
   paramsB.Init();
   paramsB.client_id = "t15_pub";
   paramsB.username = InpUsername;
   paramsB.password = InpPassword;
   paramsB.keep_alive = 60;
   paramsB.clean_start = true;

   Assert(clientA1.Connect(InpHost, (ushort)InpPort, paramsA1, InpTLS), "ClientA1 connect");
   Assert(clientA2.Connect(InpHost, (ushort)InpPort, paramsA2, InpTLS), "ClientA2 connect");
   Assert(clientA3.Connect(InpHost, (ushort)InpPort, paramsA3, InpTLS), "ClientA3 connect");
   Assert(clientB.Connect(InpHost, (ushort)InpPort, paramsB, InpTLS), "ClientB connect");

   clientA1.SetCallback(OnMsgA1);
   clientA2.SetCallback(OnMsgA2);
   clientA3.SetCallback(OnMsgA3);

   Assert(clientA1.Subscribe("test/t15", 0), "ClientA1 subscribe test/t15");
   Assert(clientA2.Subscribe("test/t15", 0), "ClientA2 subscribe test/t15");
   Assert(clientA3.Subscribe("test/t15", 0), "ClientA3 subscribe test/t15");

   Sleep(100);
   clientA1.Loop();
   clientA2.Loop();
   clientA3.Loop();

   Assert(clientB.Publish("test/t15", "broadcast", 0), "ClientB publish broadcast");

   for(int i = 0; i < 50 && (!g_received_a1 || !g_received_a2 || !g_received_a3); i++)
     {
      Sleep(10);
      clientA1.Loop();
      clientA2.Loop();
      clientA3.Loop();
     }

   Assert(g_received_a1, "ClientA1 received message");
   Assert(g_payload_a1 == "broadcast", "ClientA1 payload == 'broadcast'");
   Assert(g_received_a2, "ClientA2 received message");
   Assert(g_payload_a2 == "broadcast", "ClientA2 payload == 'broadcast'");
   Assert(g_received_a3, "ClientA3 received message");
   Assert(g_payload_a3 == "broadcast", "ClientA3 payload == 'broadcast'");

   clientA1.Disconnect();
   clientA2.Disconnect();
   clientA3.Disconnect();
   clientB.Disconnect();

   Print("=== T15: ", g_pass, " passed, ", g_fail, " failed ===");
}
