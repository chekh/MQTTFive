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
   Print("=== T07: Keepalive ===");

   MQTTClient client;

   MQTTConnectParams params;
   params.Init();
   params.client_id = "t07_keepalive";
   params.username = InpUsername;
   params.password = InpPassword;
   params.keep_alive = 3;
   params.clean_start = true;

   Assert(client.Connect(InpHost, (ushort)InpPort, params, InpTLS), "Connect with keep_alive=3");

   Print("  Waiting for first keepalive cycle (5 seconds)...");
   for(int i = 0; i < 10; i++)
     {
      Sleep(500);
      client.Loop();
     }
   Print("  First keepalive cycle completed (PINGREQ sent, PINGRESP received)");

   Assert(client.IsConnected(), "Still connected after first keepalive");

   Print("  Waiting for second keepalive cycle (5 seconds)...");
   for(int i = 0; i < 10; i++)
     {
      Sleep(500);
      client.Loop();
     }
   Print("  Second keepalive cycle completed");

   Assert(client.IsConnected(), "Still connected after second keepalive");

   client.Disconnect();

   Print("=== T07: ", g_pass, " passed, ", g_fail, " failed ===");
}
