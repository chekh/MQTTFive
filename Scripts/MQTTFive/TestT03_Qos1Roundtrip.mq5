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

bool  g_received_a = false;
string g_topic_a = "";
string g_payload_a = "";

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
   g_topic_a = topic;
   g_payload_a = CharArrayToString(payload, 0, (int)payload_len);
   g_received_a = true;
}

void OnStart()
{
   Print("=== T03: QoS 1 Roundtrip ===");

   MQTTClient clientA;
   MQTTClient clientB;

   MQTTConnectParams paramsA;
   paramsA.Init();
   paramsA.client_id = "t03_sub";
   paramsA.username = InpUsername;
   paramsA.password = InpPassword;
   paramsA.keep_alive = 60;
   paramsA.clean_start = true;

   MQTTConnectParams paramsB;
   paramsB.Init();
   paramsB.client_id = "t03_pub";
   paramsB.username = InpUsername;
   paramsB.password = InpPassword;
   paramsB.keep_alive = 60;
   paramsB.clean_start = true;

   Assert(clientA.Connect(InpHost, (ushort)InpPort, paramsA, InpTLS), "ClientA connect");
   Assert(clientB.Connect(InpHost, (ushort)InpPort, paramsB, InpTLS), "ClientB connect");

   clientA.SetCallback(OnMsgA);

   Assert(clientA.Subscribe("test/t03", 1), "ClientA subscribe test/t03 QoS 1");

   Sleep(100);
   clientA.Loop();

   Assert(clientB.Publish("test/t03", "qos1_test", 1), "ClientB publish test/t03 QoS 1");

   for(int i = 0; i < 50 && !g_received_a; i++)
     {
      Sleep(10);
      clientA.Loop();
     }

   Assert(g_received_a, "Subscriber received message");
   Assert(g_topic_a == "test/t03", "Topic matches");
   Assert(g_payload_a == "qos1_test", "Payload matches");

   for(int i = 0; i < 10; i++)
     {
      Sleep(10);
      clientB.Loop();
     }

   Assert(clientB.IsConnected(), "Publisher still connected (PUBACK received)");

   clientA.Disconnect();
   clientB.Disconnect();

   Print("=== T03: ", g_pass, " passed, ", g_fail, " failed ===");
}
