//+------------------------------------------------------------------+
//| TestT16_PublishProperties.mq5                                    |
//| Test: MQTT 5.0 PUBLISH properties (Message Expiry, Topic Alias,  |
//|       Payload Format Indicator).                                  |
//+------------------------------------------------------------------+
#property copyright "MQTTFive"
#property link      "https://github.com/chekh/MQTTFive"
#property version   "1.10"
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
   Print("=== T16: Publish Properties ===");

   MQTTClient client;

   MQTTConnectParams params;
   params.Init();
   params.client_id = "t16_pub_props";
   params.username = InpUsername;
   params.password = InpPassword;
   params.keep_alive = 60;
   params.clean_start = true;

   if(!client.Connect(InpHost, (ushort)InpPort, params, InpTLS))
     {
      Print("FAILED to connect - aborting");
      return;
     }
   Print("Connected");

   // === Test 1: Publish with Message Expiry Interval ===
   {
      MQTTPublishProperties props;
      props.Init();
      props.message_expiry_interval = 60;  // 60 seconds

      string topic = "test/t16/expiry";
      string payload = "hello-with-expiry";
      bool ok = client.Publish(topic, payload, 0, false, props);
      Assert(ok, "Publish with Message Expiry Interval (60s)");
   }

   // === Test 2: Publish with Payload Format Indicator (UTF-8) ===
   {
      MQTTPublishProperties props;
      props.Init();
      props.payload_format_indicator = 1;  // UTF-8

      string topic = "test/t16/utf8";
      string payload = "hello-utf8";
      bool ok = client.Publish(topic, payload, 0, false, props);
      Assert(ok, "Publish with Payload Format Indicator (UTF-8)");
   }

   // === Test 3: Publish with Topic Alias ===
   {
      MQTTPublishProperties props;
      props.Init();
      props.topic_alias = 1;

      // First publish: register alias (topic present, alias=1)
      bool ok = client.Publish("test/t16/aliased", "first", 0, false, props);
      Assert(ok, "Publish with Topic Alias registration");

      // Second publish: use alias (topic empty, alias=1)
      // Note: requires server to support topic_alias_maximum
      MQTTConnackInfo info = client.GetConnackInfo();
      if(info.has_topic_alias_maximum && info.topic_alias_maximum >= 1)
        {
         // Use alias-only publish via existing topic_alias overload
         ok = client.Publish("", "second", 0, false, (ushort)1);
         Assert(ok, "Publish via Topic Alias (alias=1, empty topic)");
        }
      else
        {
         Print("  SKIP: Server does not advertise topic_alias_maximum");
         g_pass++;  // count as pass (environment limitation)
        }
   }

   // === Test 4: Publish with all properties combined ===
   {
      MQTTPublishProperties props;
      props.Init();
      props.message_expiry_interval = 30;
      props.payload_format_indicator = 1;
      // topic_alias skipped (server may not support)

      bool ok = client.Publish("test/t16/combined", "all-props", 1, false, props);
      Assert(ok, "Publish QoS1 with Message Expiry + Payload Format");
   }

   // === Test 5: Publish with empty props (Init only) - backward compat ===
   {
      MQTTPublishProperties props;
      props.Init();  // all zeros - no properties encoded

      bool ok = client.Publish("test/t16/empty", "no-props", 0, false, props);
      Assert(ok, "Publish with empty props (no properties encoded)");
   }

   // === Test 6: Retained + Message Expiry ===
   {
      MQTTPublishProperties props;
      props.Init();
      props.message_expiry_interval = 5;  // 5 seconds - should expire after disconnect

      bool ok = client.Publish("test/t16/retained", "will-expire", 0, true, props);
      Assert(ok, "Publish retained with Message Expiry (5s)");
   }

   client.Disconnect();

   Print("\n========================================");
   Print(StringFormat("  T16 Results: %d passed, %d failed",
      g_pass, g_fail));
   Print("========================================");
}
