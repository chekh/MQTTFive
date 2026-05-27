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
   Print("=== T06: Will Message ===");

   MQTTClient *clientA = new MQTTClient();
   MQTTClient *clientB = new MQTTClient();

   MQTTConnectParams paramsA;
   paramsA.Init();
   paramsA.client_id = "t06_sub";
   paramsA.username = InpUsername;
   paramsA.password = InpPassword;
   paramsA.keep_alive = 60;
   paramsA.clean_start = true;

   MQTTConnectParams paramsB;
   paramsB.Init();
   paramsB.client_id = "t06_will";
   paramsB.username = InpUsername;
   paramsB.password = InpPassword;
   paramsB.keep_alive = 60;
   paramsB.clean_start = true;
   paramsB.will_topic = "test/t06/will";
   paramsB.will_payload = "client_died";
   paramsB.will_qos = 0;
   paramsB.will_retain = false;
   paramsB.will_props.will_delay_interval = 1;

   Assert(clientA->Connect(InpHost, (ushort)InpPort, paramsA, InpTLS), "ClientA connect");
   Assert(clientB->Connect(InpHost, (ushort)InpPort, paramsB, InpTLS), "ClientB connect with will");

   clientA->SetCallback(OnMsgA);

   Assert(clientA->Subscribe("test/t06/will", 0), "ClientA subscribe test/t06/will QoS 0");

   Sleep(100);
   clientA->Loop();

   clientB->SetCallback(NULL);
   delete clientB;

   Print("  ClientB deleted (abnormal disconnect), waiting for will...");

   for(int i = 0; i < 100 && !g_received_a; i++)
     {
      Sleep(100);
      clientA->Loop();
     }

   Assert(g_received_a, "Will message received");
   Assert(g_topic_a == "test/t06/will", "Will topic matches");
   Assert(g_payload_a == "client_died", "Will payload matches");

   clientA->Disconnect();
   delete clientA;

   Print("=== T06: ", g_pass, " passed, ", g_fail, " failed ===");
}
