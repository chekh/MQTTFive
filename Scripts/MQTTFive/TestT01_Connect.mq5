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
   Print("=== T01: Connect/Disconnect ===");

   MQTTClient client;

   MQTTConnectParams params;
   params.Init();
   params.client_id = "t01_test";
   params.username = InpUsername;
   params.password = InpPassword;
   params.keep_alive = 60;
   params.clean_start = true;

   bool connected = client.Connect(InpHost, (ushort)InpPort, params, InpTLS);
   Assert(connected, "Connect succeeded");

   Assert(client.IsConnected(), "IsConnected == true after connect");

   MQTTConnackInfo info = client.GetConnackInfo();
   Assert(info.reason_code == 0x00, "CONNACK reason_code == 0x00");

   Print("  CONNACK properties:");
   Print("    session_present          = ", info.session_present);
   Print("    has_receive_maximum      = ", info.has_receive_maximum,
         "  value = ", info.receive_maximum);
   Print("    has_maximum_qos          = ", info.has_maximum_qos,
         "  value = ", info.maximum_qos);
   Print("    has_retain_available     = ", info.has_retain_available,
         "  value = ", info.retain_available);
   Print("    has_topic_alias_maximum  = ", info.has_topic_alias_maximum,
         "  value = ", info.topic_alias_maximum);
   Print("    has_server_keep_alive    = ", info.has_server_keep_alive,
         "  value = ", info.server_keep_alive);
   Print("    has_maximum_packet_size  = ", info.has_maximum_packet_size,
         "  value = ", info.maximum_packet_size);
   Print("    has_session_expiry       = ", info.has_session_expiry,
         "  value = ", info.session_expiry_interval);
   Print("    has_assigned_client_id   = ", info.has_assigned_client_id,
         "  value = ", info.assigned_client_id);

   Assert(info.has_receive_maximum == true, "has_receive_maximum == true");
   Assert(info.receive_maximum > 0, "receive_maximum > 0");

   client.Disconnect();
   Assert(!client.IsConnected(), "IsConnected == false after disconnect");

   Print("=== T01: ", g_pass, " passed, ", g_fail, " failed ===");
}
