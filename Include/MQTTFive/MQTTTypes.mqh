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
//| Property identifiers (MQTT 5.0 Section 2.2.2)                     |
//+------------------------------------------------------------------+
enum ENUM_MQTT_PROPERTY_ID
  {
   MQTT_PROP_SESSION_EXPIRY_INTERVAL  = 0x11,
   MQTT_PROP_RECEIVE_MAXIMUM          = 0x21,
   MQTT_PROP_MAXIMUM_QOS              = 0x24,
   MQTT_PROP_RETAIN_AVAILABLE         = 0x25,
   MQTT_PROP_MAXIMUM_PACKET_SIZE      = 0x27,
   MQTT_PROP_ASSIGNED_CLIENT_ID       = 0x12,
   MQTT_PROP_TOPIC_ALIAS_MAXIMUM      = 0x22,
   MQTT_PROP_TOPIC_ALIAS              = 0x23,
   MQTT_PROP_SERVER_KEEP_ALIVE        = 0x13,
   MQTT_PROP_WILL_DELAY_INTERVAL      = 0x18,
   MQTT_PROP_PAYLOAD_FORMAT_INDICATOR = 0x01,
   MQTT_PROP_MESSAGE_EXPIRY_INTERVAL  = 0x02,
   MQTT_PROP_CONTENT_TYPE             = 0x03,
   MQTT_PROP_USER_PROPERTY            = 0x26,
   MQTT_PROP_REASON_STRING            = 0x1F
  };

//+------------------------------------------------------------------+
//| CONNACK parsed info                                               |
//+------------------------------------------------------------------+
struct MQTTConnackInfo
  {
   bool              session_present;
   uchar             reason_code;
   uint              session_expiry_interval;
   ushort            receive_maximum;
   uchar             maximum_qos;
   bool              retain_available;
   uint              maximum_packet_size;
   string            assigned_client_id;
   ushort            topic_alias_maximum;
   ushort            server_keep_alive;
   bool              has_session_expiry;
   bool              has_receive_maximum;
   bool              has_maximum_qos;
   bool              has_retain_available;
   bool              has_maximum_packet_size;
   bool              has_assigned_client_id;
   bool              has_topic_alias_maximum;
   bool              has_server_keep_alive;

   void              Init()
     {
      session_present = false; reason_code = 0xFF;
      session_expiry_interval = 0; receive_maximum = 65535;
      maximum_qos = 2; retain_available = true;
      maximum_packet_size = 0; assigned_client_id = "";
      topic_alias_maximum = 0; server_keep_alive = 0;
      has_session_expiry = false; has_receive_maximum = false;
      has_maximum_qos = false; has_retain_available = false;
      has_maximum_packet_size = false; has_assigned_client_id = false;
      has_topic_alias_maximum = false; has_server_keep_alive = false;
     }
  };

//+------------------------------------------------------------------+
//| Will properties                                                   |
//+------------------------------------------------------------------+
struct MQTTWillProperties
  {
   uint              will_delay_interval;
   uchar             payload_format_indicator;
   uint              message_expiry_interval;
   string            content_type;

   void              Init()
     {
      will_delay_interval = 0;
      payload_format_indicator = 0;
      message_expiry_interval = 0;
      content_type = "";
     }
  };

//+------------------------------------------------------------------+
//| Subscription options (MQTT 5.0 Section 3.8.3.1)                   |
//+------------------------------------------------------------------+
struct MQTTSubscriptionOptions
  {
   uchar             maximum_qos;
   bool              no_local;
   bool              retain_as_published;
   uchar             retain_handling;

   void              Init()
     {
      maximum_qos = 0; no_local = false;
      retain_as_published = false; retain_handling = 0;
     }

   uchar             ToByte() const
     {
      return (uchar)((maximum_qos & 0x03)
           | ((no_local ? 1 : 0) << 2)
           | ((retain_as_published ? 1 : 0) << 3)
           | ((retain_handling & 0x03) << 4));
     }
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
   uint              session_expiry_interval;
   ushort            receive_maximum;
   uint              maximum_packet_size;
   ushort            topic_alias_maximum;
   MQTTWillProperties will_props;

   void              Init()
     {
      client_id = ""; username = ""; password = "";
      keep_alive = 60; clean_start = true;
      will_topic = ""; will_payload = "";
      will_qos = 0; will_retain = false;
      session_expiry_interval = 0; receive_maximum = 65535;
      maximum_packet_size = 0; topic_alias_maximum = 0;
      will_props.Init();
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
   string               topic_filter;
   MQTTSubscriptionOptions options;

   void              Init()
     {
      topic_filter = "";
      options.Init();
     }
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
