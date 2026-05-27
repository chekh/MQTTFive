//+------------------------------------------------------------------+
//|                                               MQTTFive/Types.mqh |
//|                    MQTT 5.0 Client Library for MQL5               |
//|                      https://github.com/chekh/MQTTFive            |
//+------------------------------------------------------------------+
#ifndef _MQTTFIVE_TYPES_MQH_
#define _MQTTFIVE_TYPES_MQH_

//+------------------------------------------------------------------+
//| Packet type values (shifted << 4, ready for Fixed Header byte 1) |
//+------------------------------------------------------------------+
enum ENUM_MQTT_PKT
  {
   MQTT_PKT_CONNECT     = 0x10,
   MQTT_PKT_CONNACK     = 0x20,
   MQTT_PKT_PUBLISH     = 0x30,
   MQTT_PKT_PUBACK      = 0x40,
   MQTT_PKT_PUBREC      = 0x50,
   MQTT_PKT_PUBREL      = 0x62,
   MQTT_PKT_PUBCOMP     = 0x70,
   MQTT_PKT_SUBSCRIBE   = 0x82,
   MQTT_PKT_SUBACK      = 0x90,
   MQTT_PKT_UNSUBSCRIBE = 0xA2,
   MQTT_PKT_UNSUBACK    = 0xB0,
   MQTT_PKT_PINGREQ     = 0xC0,
   MQTT_PKT_PINGRESP    = 0xD0,
   MQTT_PKT_DISCONNECT  = 0xE0,
   MQTT_PKT_AUTH        = 0xF0
  };

//+------------------------------------------------------------------+
//| Connection states                                                 |
//+------------------------------------------------------------------+
enum ENUM_MQTT_STATE
  {
   MQTT_STATE_DISCONNECTED = -1,
   MQTT_STATE_CONNECTED    =  0
  };

//+------------------------------------------------------------------+
//| CONNACK reason codes (common subset)                              |
//+------------------------------------------------------------------+
enum ENUM_MQTT_CONNACK
  {
   MQTT_CONNACK_SUCCESS             = 0x00,
   MQTT_CONNACK_UNSPECIFIED_ERROR   = 0x80,
   MQTT_CONNACK_MALFORMED_PACKET    = 0x81,
   MQTT_CONNACK_PROTOCOL_ERROR      = 0x82,
   MQTT_CONNACK_UNSUPPORTED_VERSION = 0x84,
   MQTT_CONNACK_INVALID_CLIENT_ID   = 0x85,
   MQTT_CONNACK_BAD_CREDENTIALS     = 0x86,
   MQTT_CONNACK_NOT_AUTHORIZED      = 0x87,
   MQTT_CONNACK_SERVER_UNAVAILABLE  = 0x88,
   MQTT_CONNACK_SERVER_BUSY         = 0x89,
   MQTT_CONNACK_BANNED              = 0x8A
  };

//+------------------------------------------------------------------+
//| SUBACK reason codes                                               |
//+------------------------------------------------------------------+
enum ENUM_MQTT_SUBACK
  {
   MQTT_SUBACK_GRANTED_QOS0         = 0x00,
   MQTT_SUBACK_GRANTED_QOS1         = 0x01,
   MQTT_SUBACK_GRANTED_QOS2         = 0x02,
   MQTT_SUBACK_UNSPECIFIED_ERROR    = 0x80,
   MQTT_SUBACK_NOT_AUTHORIZED       = 0x87,
   MQTT_SUBACK_TOPIC_FILTER_INVALID = 0x8F,
   MQTT_SUBACK_PACKET_ID_IN_USE     = 0x91
  };

//+------------------------------------------------------------------+
//| CONNECT parameters                                                |
//+------------------------------------------------------------------+
struct MQTTConnectParams
  {
   string            client_id;
   string            username;
   string            password;
   ushort            keep_alive;
   bool              clean_start;
   string            will_topic;
   string            will_payload;
   uchar             will_qos;
   bool              will_retain;

   void              Init()
     {
      client_id = ""; username = ""; password = "";
      keep_alive = 60; clean_start = true;
      will_topic = ""; will_payload = "";
      will_qos = 0; will_retain = false;
     }
  };

//+------------------------------------------------------------------+
//| Incoming PUBLISH message                                          |
//+------------------------------------------------------------------+
struct MQTTPublishMessage
  {
   string            topic;
   uchar             payload[];
   uint              payload_len;
   uchar             qos;
   bool              retain;
   bool              dup;
   ushort            packet_id;
  };

//+------------------------------------------------------------------+
//| Subscribe parameters                                              |
//+------------------------------------------------------------------+
struct MQTTSubscribeParams
  {
   string            topic_filter;
   uchar             qos;
  };

//+------------------------------------------------------------------+
//| Connect Flags bit masks (MQTT 5.0 Section 3.1.2.3)               |
//+------------------------------------------------------------------+
#define MQTT_FLAG_CLEAN_START    0x02
#define MQTT_FLAG_WILL           0x04
#define MQTT_FLAG_WILL_QOS_MASK  0x18
#define MQTT_FLAG_WILL_RETAIN    0x20
#define MQTT_FLAG_PASSWORD       0x40
#define MQTT_FLAG_USERNAME       0x80

//+------------------------------------------------------------------+
//| PUBLISH flags (MQTT 5.0 Section 3.3.1)                           |
//+------------------------------------------------------------------+
#define MQTT_PUB_FLAG_RETAIN     0x01
#define MQTT_PUB_FLAG_QOS1       0x02
#define MQTT_PUB_FLAG_QOS2       0x04
#define MQTT_PUB_FLAG_DUP        0x08

#endif
