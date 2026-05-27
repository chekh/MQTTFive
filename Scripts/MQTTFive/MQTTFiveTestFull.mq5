#property copyright "MQTTFive"
#property link      "https://github.com/chekh/MQTTFive"
#property version   "2.00"
#property script_show_inputs

input string InpHost       = "127.0.0.1";
input int    InpPort       = 1883;
input string InpClientId   = "mql5_full_test";
input string InpUsername   = "";
input string InpPassword   = "";
input bool   InpTLS        = false;
input int    TestGroup     = 0;

#include <MQTTFive/MQTTClient.mqh>

int g_pass = 0;
int g_fail = 0;

void Assert(bool condition, string test_name)
  {
   if(condition)
     {
      g_pass++;
      Print("PASS: ", test_name);
     }
   else
     {
      g_fail++;
      Print("FAIL: ", test_name);
     }
  }

MQTTClient *client;

void OnMessage(string &topic, uchar &payload[], uint payload_len)
  {
   string msg = CharArrayToString(payload, 0, (int)payload_len);
   Print("MSG: topic=", topic, " len=", payload_len, " data=", msg);
  }

void TestProperties()
  {
   Print("=== Group 1: Properties ===");
   client = new MQTTClient();
   client.SetLog(true);
   client.SetCallback(OnMessage);

   MQTTConnectParams params;
   params.Init();
   params.client_id = InpClientId;
   params.username = InpUsername;
   params.password = InpPassword;
   params.keep_alive = 60;
   params.session_expiry_interval = 300;
   params.receive_maximum = 10;

   Assert(client.Connect(InpHost, (ushort)InpPort, params, InpTLS),
          "Connect with properties");

   MQTTConnackInfo info = client.GetConnackInfo();
   Print("CONNACK: reason=", info.reason_code,
         " session_present=", info.session_present,
         " max_qos=", info.maximum_qos,
         " retain_available=", info.retain_available,
         " topic_alias_max=", info.topic_alias_maximum,
         " server_keep_alive=", info.server_keep_alive,
         " receive_max=", info.receive_maximum,
         " max_packet_size=", info.maximum_packet_size);

   Assert(info.reason_code == 0x00, "CONNACK success");

   client.Disconnect();
   delete client;
  }

void TestWillProperties()
  {
   Print("=== Group 2: Will Properties ===");
   client = new MQTTClient();
   client.SetLog(true);

   MQTTConnectParams params;
   params.Init();
   params.client_id = "will_test";
   params.keep_alive = 60;
   params.will_topic = "mql5/test/will";
   params.will_payload = "goodbye";
   params.will_retain = false;
   params.will_props.will_delay_interval = 5;
   params.will_props.content_type = "text/plain";

   Assert(client.Connect(InpHost, (ushort)InpPort, params, InpTLS),
          "Connect with Will properties");

   client.Subscribe("mql5/test/will", 0);
   client.Disconnect();
   delete client;
  }

void TestSubscriptionOptions()
  {
   Print("=== Group 3: Subscription Options ===");
   client = new MQTTClient();
   client.SetLog(true);

   MQTTConnectParams params;
   params.Init();
   params.client_id = "subopt_test";
   params.keep_alive = 60;

   Assert(client.Connect(InpHost, (ushort)InpPort, params, InpTLS),
          "Connect for subscription options");

   MQTTSubscribeParams sp;
   sp.Init();
   sp.topic_filter = "mql5/test/#";
   sp.options.maximum_qos = 1;
   sp.options.no_local = true;
   Assert(client.Subscribe(sp), "Subscribe with full options");

   Assert(client.Subscribe("mql5/test2/#", 0), "Subscribe QoS 0");
   Assert(client.Subscribe("mql5/test3/#", 1), "Subscribe QoS 1");

   client.Disconnect();
   delete client;
  }

void TestUnsubscribe()
  {
   Print("=== Group 4: UNSUBACK ===");
   client = new MQTTClient();
   client.SetLog(true);

   MQTTConnectParams params;
   params.Init();
   params.client_id = "unsub_test";
   params.keep_alive = 60;

   Assert(client.Connect(InpHost, (ushort)InpPort, params, InpTLS),
          "Connect for unsubscribe test");

   Assert(client.Subscribe("mql5/test/unsub", 0), "Subscribe before unsubscribe");
   client.Loop();
   Sleep(100);
   Assert(client.Unsubscribe("mql5/test/unsub"), "Unsubscribe");
   client.Loop();
   Sleep(100);

   client.Disconnect();
   delete client;
  }

void TestQos2Send()
  {
   Print("=== Group 5: QoS 2 send ===");
   client = new MQTTClient();
   client.SetLog(true);
   client.SetCallback(OnMessage);

   MQTTConnectParams params;
   params.Init();
   params.client_id = "qos2_send_test";
   params.keep_alive = 60;

   Assert(client.Connect(InpHost, (ushort)InpPort, params, InpTLS),
          "Connect for QoS 2 send");

   Assert(client.Publish("mql5/test/qos2", "QoS2 message", 2, false),
          "Publish QoS 2");

   int count = 0;
   while(!IsStopped() && count < 10)
     {
      client.Loop();
      Sleep(100);
      count++;
     }

   client.Disconnect();
   delete client;
  }

void TestQos2Receive()
  {
   Print("=== Group 6: QoS 2 receive ===");
   client = new MQTTClient();
   client.SetLog(true);
   client.SetCallback(OnMessage);

   MQTTConnectParams params;
   params.Init();
   params.client_id = "qos2_recv_test";
   params.keep_alive = 60;

   Assert(client.Connect(InpHost, (ushort)InpPort, params, InpTLS),
          "Connect for QoS 2 receive");

   Assert(client.Subscribe("mql5/test/qos2in", 2), "Subscribe QoS 2");

   Print("Waiting for QoS 2 messages on mql5/test/qos2in...");
   Print("Publish from another client: mosquitto_pub -V 5 -t mql5/test/qos2in -m test -q 2");

   int count = 0;
   while(!IsStopped() && count < 30)
     {
      client.Loop();
      Sleep(1000);
      count++;
     }

   client.Disconnect();
   delete client;
  }

void TestQos1Inflight()
  {
   Print("=== Group 7: QoS 1 inflight ===");
   client = new MQTTClient();
   client.SetLog(true);
   client.SetCallback(OnMessage);

   MQTTConnectParams params;
   params.Init();
   params.client_id = "inflight_test";
   params.keep_alive = 60;

   Assert(client.Connect(InpHost, (ushort)InpPort, params, InpTLS),
          "Connect for inflight test");

   for(int i = 0; i < 5; i++)
     {
      string msg = StringFormat("inflight_%d", i);
      Assert(client.Publish("mql5/test/inflight", msg, 1, false),
             StringFormat("Publish QoS 1 #%d", i));
      client.Loop();
      Sleep(50);
     }

   int count = 0;
   while(!IsStopped() && count < 10)
     {
      client.Loop();
      Sleep(100);
      count++;
     }

   client.Disconnect();
   delete client;
  }

void TestFlowControl()
  {
   Print("=== Group 8: Flow control ===");
   client = new MQTTClient();
   client.SetLog(true);

   MQTTConnectParams params;
   params.Init();
   params.client_id = "flow_test";
   params.keep_alive = 60;
   params.receive_maximum = 2;

   Assert(client.Connect(InpHost, (ushort)InpPort, params, InpTLS),
          "Connect with Receive Maximum = 2");

   Assert(client.Publish("mql5/test/flow", "msg1", 1, false), "Flow: msg1 OK");
   Assert(client.Publish("mql5/test/flow", "msg2", 1, false), "Flow: msg2 OK");
   Print("Note: msg3 should block if server enforces Receive Maximum = 2");

   int count = 0;
   while(!IsStopped() && count < 15)
     {
      client.Loop();
      Sleep(100);
      count++;
     }

   client.Disconnect();
   delete client;
  }

void TestTopicAlias()
  {
   Print("=== Group 9: Topic Alias ===");
   client = new MQTTClient();
   client.SetLog(true);
   client.SetCallback(OnMessage);

   MQTTConnectParams params;
   params.Init();
   params.client_id = "alias_test";
   params.keep_alive = 60;
   params.topic_alias_maximum = 5;

   Assert(client.Connect(InpHost, (ushort)InpPort, params, InpTLS),
          "Connect with Topic Alias Maximum = 5");

   MQTTConnackInfo info = client.GetConnackInfo();
   ushort max_alias = info.has_topic_alias_maximum ? info.topic_alias_maximum : (ushort)5;
   Assert(max_alias > 0, "Server supports Topic Alias");

   if(max_alias > 0)
     {
      Assert(client.Publish("mql5/test/alias/topic", "first", 0, false, 1),
             "Publish with alias=1 (register)");
      Assert(client.Publish("", "second", 0, false, 1),
             "Publish with alias=1 (reuse, empty topic)");
     }

   client.Disconnect();
   delete client;
  }

void OnStart()
  {
   Print("=== MQTTFive Full Test Suite ===");
   Print("TestGroup: ", TestGroup, " (0=all)");

   if(TestGroup == 0 || TestGroup == 1) TestProperties();
   if(TestGroup == 0 || TestGroup == 2) TestWillProperties();
   if(TestGroup == 0 || TestGroup == 3) TestSubscriptionOptions();
   if(TestGroup == 0 || TestGroup == 4) TestUnsubscribe();
   if(TestGroup == 0 || TestGroup == 5) TestQos2Send();
   if(TestGroup == 0 || TestGroup == 6) TestQos2Receive();
   if(TestGroup == 0 || TestGroup == 7) TestQos1Inflight();
   if(TestGroup == 0 || TestGroup == 8) TestFlowControl();
   if(TestGroup == 0 || TestGroup == 9) TestTopicAlias();

   Print("=== Results: ", g_pass, " passed, ", g_fail, " failed ===");
  }
