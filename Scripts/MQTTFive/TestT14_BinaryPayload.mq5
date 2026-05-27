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
uint g_payload_len = 0;
uchar g_rx_payload[];

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
   g_payload_len = payload_len;
   ArrayResize(g_rx_payload, (int)payload_len);
   if(payload_len > 0)
      ArrayCopy(g_rx_payload, payload, 0, 0, (int)payload_len);
   g_received = true;
}

void OnStart()
{
   Print("=== T14: Binary Payload ===");

   MQTTClient clientA;
   MQTTClient clientB;

   MQTTConnectParams paramsA;
   paramsA.Init();
   paramsA.client_id = "t14_sub";
   paramsA.username = InpUsername;
   paramsA.password = InpPassword;
   paramsA.keep_alive = 60;
   paramsA.clean_start = true;

   MQTTConnectParams paramsB;
   paramsB.Init();
   paramsB.client_id = "t14_pub";
   paramsB.username = InpUsername;
   paramsB.password = InpPassword;
   paramsB.keep_alive = 60;
   paramsB.clean_start = true;

   Assert(clientA.Connect(InpHost, (ushort)InpPort, paramsA, InpTLS), "ClientA connect");
   Assert(clientB.Connect(InpHost, (ushort)InpPort, paramsB, InpTLS), "ClientB connect");

   clientA.SetCallback(OnMsgA);

   Assert(clientA.Subscribe("test/t14", 0), "ClientA subscribe test/t14");

   Sleep(100);
   clientA.Loop();

   uchar bin[];
   ArrayResize(bin, 256);
   for(int i = 0; i < 256; i++)
      bin[i] = (uchar)i;

   g_received = false;
   g_payload_len = 0;

   Assert(clientB.Publish("test/t14", bin, 256, 0), "Publish binary 0x00-0xFF");

   for(int i = 0; i < 50 && !g_received; i++)
     {
      Sleep(10);
      clientA.Loop();
     }

    Assert(g_received, "Received binary message");
    Assert(g_payload_len == 256, "Payload length == 256");

    bool all_match = true;
    if(g_received && g_payload_len == 256)
      {
       for(int i = 0; i < 256 && all_match; i++)
         {
          if(g_rx_payload[i] != (uchar)i)
             all_match = false;
         }
      }
    else
      {
       all_match = false;
      }
    Assert(all_match, "All 256 bytes match (no corruption)");

   clientA.Disconnect();
   clientB.Disconnect();

   Print("=== T14: ", g_pass, " passed, ", g_fail, " failed ===");
}
