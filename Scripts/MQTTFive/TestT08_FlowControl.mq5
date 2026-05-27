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

void OnStart()
{
   Print("=== T08: Flow Control ===");

   MQTTClient client;

   MQTTConnectParams params;
   params.Init();
   params.client_id = "t08_flow";
   params.username = InpUsername;
   params.password = InpPassword;
   params.keep_alive = 60;
   params.clean_start = true;
   params.receive_maximum = 2;

   Assert(client.Connect(InpHost, (ushort)InpPort, params, InpTLS), "Connect with receive_maximum=2");

   MQTTConnackInfo info = client.GetConnackInfo();
   Print("  CONNACK receive_maximum = ", info.receive_maximum);

   Assert(client.Publish("test/t08", "msg1", 1), "Publish msg1 QoS 1");
   Assert(client.Publish("test/t08", "msg2", 1), "Publish msg2 QoS 1");
   Assert(client.Publish("test/t08", "msg3", 1), "Publish msg3 QoS 1");

   for(int i = 0; i < 20; i++)
     {
      Sleep(10);
      client.Loop();
     }

   Assert(client.IsConnected(), "Client still connected after PUBACKs");

   client.Disconnect();

   Print("=== T08: ", g_pass, " passed, ", g_fail, " failed ===");
}
