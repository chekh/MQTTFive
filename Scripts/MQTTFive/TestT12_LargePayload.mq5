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

uint g_payload_len = 0;
bool g_received = false;
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
   Print("=== T12: Large Payload ===");

   MQTTClient clientA;
   MQTTClient clientB;

   MQTTConnectParams paramsA;
   paramsA.Init();
   paramsA.client_id = "t12_sub";
   paramsA.username = InpUsername;
   paramsA.password = InpPassword;
   paramsA.keep_alive = 60;
   paramsA.clean_start = true;

   MQTTConnectParams paramsB;
   paramsB.Init();
   paramsB.client_id = "t12_pub";
   paramsB.username = InpUsername;
   paramsB.password = InpPassword;
   paramsB.keep_alive = 60;
   paramsB.clean_start = true;

   Assert(clientA.Connect(InpHost, (ushort)InpPort, paramsA, InpTLS), "ClientA connect");
   Assert(clientB.Connect(InpHost, (ushort)InpPort, paramsB, InpTLS), "ClientB connect");

   clientA.SetCallback(OnMsgA);

   Assert(clientA.Subscribe("test/t12", 0), "ClientA subscribe test/t12");

   Sleep(100);
   clientA.Loop();

   uchar payload1kb[1024];
   ArrayInitialize(payload1kb, 0xAA);

   g_received = false;
   g_payload_len = 0;

   Assert(clientB.Publish("test/t12", payload1kb, 1024, 0), "Publish 1KB payload");

   for(int i = 0; i < 50 && !g_received; i++)
     {
      Sleep(10);
      clientA.Loop();
     }

   Assert(g_received, "Received 1KB message");
   Assert(g_payload_len == 1024, "1KB payload_len == 1024");
   Assert(g_rx_payload[0] == 0xAA, "1KB first byte == 0xAA");
   Assert(g_rx_payload[1023] == 0xAA, "1KB last byte == 0xAA");

   uchar payload10kb[];
   ArrayResize(payload10kb, 10240);
   ArrayInitialize(payload10kb, 0xBB);

   g_received = false;
   g_payload_len = 0;

   Assert(clientB.Publish("test/t12", payload10kb, 10240, 0), "Publish 10KB payload");

   for(int i = 0; i < 50 && !g_received; i++)
     {
      Sleep(10);
      clientA.Loop();
     }

   Assert(g_received, "Received 10KB message");
   Assert(g_payload_len == 10240, "10KB payload_len == 10240");
   Assert(g_rx_payload[0] == 0xBB, "10KB first byte == 0xBB");
   Assert(g_rx_payload[10239] == 0xBB, "10KB last byte == 0xBB");

   clientA.Disconnect();
   clientB.Disconnect();

   Print("=== T12: ", g_pass, " passed, ", g_fail, " failed ===");
}
