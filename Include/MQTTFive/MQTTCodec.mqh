//+------------------------------------------------------------------+
//|                                             MQTTFive/Codec.mqh   |
//|                    MQTT 5.0 Client Library for MQL5               |
//+------------------------------------------------------------------+
#ifndef _MQTTFIVE_CODEC_MQH_
#define _MQTTFIVE_CODEC_MQH_

#include <MQTTFive/MQTTTypes.mqh>
#include <MQTTFive/MQTTBuffer.mqh>

class MQTTCodec
  {
private:
   static void       EncodePropertyByte(MQTTBuffer &buf, uchar prop_id, uchar value)
     {
      buf.WriteByte(prop_id);
      buf.WriteByte(value);
     }

   static void       EncodePropertyU16(MQTTBuffer &buf, uchar prop_id, ushort value)
     {
      buf.WriteByte(prop_id);
      buf.WriteU16(value);
     }

   static void       EncodePropertyU32(MQTTBuffer &buf, uchar prop_id, uint value)
     {
      buf.WriteByte(prop_id);
      buf.WriteU32(value);
     }

   static void       EncodePropertyString(MQTTBuffer &buf, uchar prop_id, string value)
     {
      if(value == "") return;
      buf.WriteByte(prop_id);
      buf.WriteString(value);
     }

   static void       WriteConnectProperties(MQTTBuffer &buf, MQTTConnectParams &params)
     {
      MQTTBuffer props;
      if(params.session_expiry_interval > 0)
         EncodePropertyU32(props, MQTT_PROP_SESSION_EXPIRY_INTERVAL, params.session_expiry_interval);
      if(params.receive_maximum < 65535)
         EncodePropertyU16(props, MQTT_PROP_RECEIVE_MAXIMUM, params.receive_maximum);
      if(params.maximum_packet_size > 0)
         EncodePropertyU32(props, MQTT_PROP_MAXIMUM_PACKET_SIZE, params.maximum_packet_size);
      if(params.topic_alias_maximum > 0)
         EncodePropertyU16(props, MQTT_PROP_TOPIC_ALIAS_MAXIMUM, params.topic_alias_maximum);

      uchar propsData[];
      props.GetData(propsData);
      buf.WriteVarInt((uint)ArraySize(propsData));
      buf.WriteRawBytes(propsData, (uint)ArraySize(propsData));
     }

   static void       WriteWillProperties(MQTTBuffer &buf, MQTTConnectParams &params)
     {
      MQTTBuffer props;
      if(params.will_props.will_delay_interval > 0)
         EncodePropertyU32(props, MQTT_PROP_WILL_DELAY_INTERVAL, params.will_props.will_delay_interval);
      if(params.will_props.payload_format_indicator > 0)
         EncodePropertyByte(props, MQTT_PROP_PAYLOAD_FORMAT_INDICATOR, params.will_props.payload_format_indicator);
      if(params.will_props.message_expiry_interval > 0)
         EncodePropertyU32(props, MQTT_PROP_MESSAGE_EXPIRY_INTERVAL, params.will_props.message_expiry_interval);
      if(params.will_props.content_type != "")
         EncodePropertyString(props, MQTT_PROP_CONTENT_TYPE, params.will_props.content_type);

      uchar propsData[];
      props.GetData(propsData);
      buf.WriteVarInt((uint)ArraySize(propsData));
      buf.WriteRawBytes(propsData, (uint)ArraySize(propsData));
     }

   static void       ParseProperties(MQTTBuffer &buf, MQTTConnackInfo &info)
     {
      bool ok;
      uint props_len = buf.ReadVarInt(ok);
      if(!ok || props_len == 0) return;
      uint end_pos = buf.ReadPosition() + props_len;
      while(buf.ReadPosition() < end_pos)
        {
         uchar prop_id;
         if(!buf.ReadByte(prop_id)) break;
         switch(prop_id)
           {
            case MQTT_PROP_SESSION_EXPIRY_INTERVAL:
               info.has_session_expiry = true;
               { uint v; if(buf.ReadU32(v)) info.session_expiry_interval = v; }
               break;
            case MQTT_PROP_RECEIVE_MAXIMUM:
               info.has_receive_maximum = true;
               { ushort v; if(buf.ReadU16(v)) info.receive_maximum = v; }
               break;
            case MQTT_PROP_MAXIMUM_QOS:
               info.has_maximum_qos = true;
               { uchar v; if(buf.ReadByte(v)) info.maximum_qos = v; }
               break;
            case MQTT_PROP_RETAIN_AVAILABLE:
               info.has_retain_available = true;
               { uchar v; if(buf.ReadByte(v)) info.retain_available = (v != 0); }
               break;
            case MQTT_PROP_MAXIMUM_PACKET_SIZE:
               info.has_maximum_packet_size = true;
               { uint v; if(buf.ReadU32(v)) info.maximum_packet_size = v; }
               break;
            case MQTT_PROP_ASSIGNED_CLIENT_ID:
               info.has_assigned_client_id = true;
               buf.ReadString(info.assigned_client_id);
               break;
            case MQTT_PROP_TOPIC_ALIAS_MAXIMUM:
               info.has_topic_alias_maximum = true;
               { ushort v; if(buf.ReadU16(v)) info.topic_alias_maximum = v; }
               break;
            case MQTT_PROP_SERVER_KEEP_ALIVE:
               info.has_server_keep_alive = true;
               { ushort v; if(buf.ReadU16(v)) info.server_keep_alive = v; }
               break;
            case MQTT_PROP_REASON_STRING:
               { string s; buf.ReadString(s); }
               break;
            case MQTT_PROP_USER_PROPERTY:
               { string k, v; buf.ReadString(k); buf.ReadString(v); }
               break;
            default:
               break;
           }
        }
      if(buf.ReadPosition() < end_pos)
         buf.SkipBytes(end_pos - buf.ReadPosition());
     }

public:

   static void       BuildPacket(uchar pkt_type, MQTTBuffer &body,
                                  MQTTBuffer &out)
     {
      out.Reset();
      uchar bodyData[];
      body.GetData(bodyData);
      uint bodyLen = ArraySize(bodyData);

      out.WriteByte(pkt_type);
      out.WriteVarInt(bodyLen);
      out.WriteRawBytes(bodyData, bodyLen);
     }

   static void       EncodeConnect(MQTTConnectParams &params, MQTTBuffer &out)
     {
      MQTTBuffer buf;
      buf.WriteU16(4);
      buf.WriteByte('M'); buf.WriteByte('Q'); buf.WriteByte('T'); buf.WriteByte('T');
      buf.WriteByte(0x05);

      uchar flags = 0;
      if(params.clean_start) flags |= MQTT_FLAG_CLEAN_START;
      if(params.will_topic != "")
        {
         flags |= MQTT_FLAG_WILL;
         flags |= (uchar)((params.will_qos & 0x03) << 3);
         if(params.will_retain) flags |= MQTT_FLAG_WILL_RETAIN;
        }
      if(params.username != "")
        {
         flags |= MQTT_FLAG_USERNAME;
         if(params.password != "") flags |= MQTT_FLAG_PASSWORD;
        }
      buf.WriteByte(flags);
      buf.WriteU16(params.keep_alive);

      WriteConnectProperties(buf, params);

      buf.WriteString(params.client_id);
      if(params.will_topic != "")
        {
         WriteWillProperties(buf, params);
         buf.WriteString(params.will_topic);
         uchar wp[];
         int wpl = StringToCharArray(params.will_payload, wp, 0, WHOLE_ARRAY, CP_UTF8);
         if(wpl > 0) wpl--;
         buf.WriteU16((ushort)wpl);
         if(wpl > 0)
            buf.WriteRawBytes(wp, (uint)wpl);
        }
      if(params.username != "")
         buf.WriteString(params.username);
      if(params.password != "")
        {
         uchar pp[];
         int ppl = StringToCharArray(params.password, pp, 0, WHOLE_ARRAY, CP_UTF8);
         if(ppl > 0) ppl--;
         buf.WriteU16((ushort)ppl);
         if(ppl > 0)
            buf.WriteRawBytes(pp, (uint)ppl);
        }

      BuildPacket(MQTT_PKT_CONNECT, buf, out);
     }

   static void       EncodePublishString(string topic, string payload,
                                          uchar qos, bool retain, ushort packet_id,
                                          ushort topic_alias, MQTTBuffer &out)
     {
      MQTTBuffer buf;
      if(topic_alias > 0 && topic == "")
         buf.WriteU16(0);
      else
         buf.WriteString(topic);
      if(qos > 0)
         buf.WriteU16(packet_id);

      MQTTBuffer props;
      if(topic_alias > 0)
         EncodePropertyU16(props, MQTT_PROP_TOPIC_ALIAS, topic_alias);
      uchar propsData[];
      props.GetData(propsData);
      buf.WriteVarInt((uint)ArraySize(propsData));
      buf.WriteRawBytes(propsData, (uint)ArraySize(propsData));

      uchar temp[];
      int byte_len = StringToCharArray(payload, temp, 0, WHOLE_ARRAY, CP_UTF8);
      if(byte_len > 0) byte_len--;
      buf.WriteRawBytes(temp, (uint)byte_len);

      uchar hdr = MQTT_PKT_PUBLISH;
      if(qos == 1) hdr |= MQTT_PUB_FLAG_QOS1;
      else if(qos == 2) hdr |= MQTT_PUB_FLAG_QOS2;
      if(retain) hdr |= MQTT_PUB_FLAG_RETAIN;
      BuildPacket(hdr, buf, out);
     }

   static void       EncodePublish(string topic, uchar &payload[], uint payload_len,
                                    uchar qos, bool retain, ushort packet_id,
                                    ushort topic_alias, MQTTBuffer &out)
     {
      MQTTBuffer buf;
      if(topic_alias > 0 && topic == "")
         buf.WriteU16(0);
      else
         buf.WriteString(topic);
      if(qos > 0)
         buf.WriteU16(packet_id);

      MQTTBuffer props;
      if(topic_alias > 0)
         EncodePropertyU16(props, MQTT_PROP_TOPIC_ALIAS, topic_alias);
      uchar propsData[];
      props.GetData(propsData);
      buf.WriteVarInt((uint)ArraySize(propsData));
      buf.WriteRawBytes(propsData, (uint)ArraySize(propsData));

      buf.WriteRawBytes(payload, payload_len);

      uchar hdr = MQTT_PKT_PUBLISH;
      if(qos == 1) hdr |= MQTT_PUB_FLAG_QOS1;
      else if(qos == 2) hdr |= MQTT_PUB_FLAG_QOS2;
      if(retain) hdr |= MQTT_PUB_FLAG_RETAIN;
      BuildPacket(hdr, buf, out);
     }

   static void       EncodeSubscribe(ushort packet_id, MQTTSubscribeParams &params,
                                      MQTTBuffer &out)
     {
      MQTTBuffer buf;
      buf.WriteU16(packet_id);
      buf.WriteByte(0x00);
      buf.WriteString(params.topic_filter);
      buf.WriteByte(params.options.ToByte());

      BuildPacket(MQTT_PKT_SUBSCRIBE, buf, out);
     }

   static void       EncodeUnsubscribe(ushort packet_id, string &topic,
                                        MQTTBuffer &out)
     {
      MQTTBuffer buf;
      buf.WriteU16(packet_id);
      buf.WriteByte(0x00);
      buf.WriteString(topic);

      BuildPacket(MQTT_PKT_UNSUBSCRIBE, buf, out);
     }

   static void       EncodePuback(ushort packet_id, MQTTBuffer &out)
     {
      out.Reset();
      out.WriteByte(MQTT_PKT_PUBACK);
      out.WriteByte(0x02);
      out.WriteU16(packet_id);
     }

   static void       EncodePubrec(ushort packet_id, MQTTBuffer &out)
     {
      out.Reset();
      out.WriteByte(MQTT_PKT_PUBREC);
      out.WriteByte(0x02);
      out.WriteU16(packet_id);
     }

   static void       EncodePubrel(ushort packet_id, MQTTBuffer &out)
     {
      out.Reset();
      out.WriteByte(MQTT_PKT_PUBREL);
      out.WriteByte(0x02);
      out.WriteU16(packet_id);
     }

   static void       EncodePubcomp(ushort packet_id, MQTTBuffer &out)
     {
      out.Reset();
      out.WriteByte(MQTT_PKT_PUBCOMP);
      out.WriteByte(0x02);
      out.WriteU16(packet_id);
     }

   static void       EncodePingreq(MQTTBuffer &out)
     {
      out.Reset();
      out.WriteByte(MQTT_PKT_PINGREQ);
      out.WriteByte(0x00);
     }

   static void       EncodeDisconnect(MQTTBuffer &out)
     {
      out.Reset();
      out.WriteByte(MQTT_PKT_DISCONNECT);
      out.WriteByte(0x00);
     }

   static void       EncodeDisconnectWithReason(uchar reason_code, uint session_expiry, MQTTBuffer &out)
     {
      MQTTBuffer buf;
      buf.WriteByte(reason_code);

      MQTTBuffer props;
      if(session_expiry > 0)
         EncodePropertyU32(props, MQTT_PROP_SESSION_EXPIRY_INTERVAL, session_expiry);
      uchar propsData[];
      props.GetData(propsData);
      buf.WriteVarInt((uint)ArraySize(propsData));
      buf.WriteRawBytes(propsData, (uint)ArraySize(propsData));

      BuildPacket(MQTT_PKT_DISCONNECT, buf, out);
     }

   static uchar      PacketType(uchar first_byte)
     {
      return first_byte & 0xF0;
     }

   static bool       DecodeConnackFull(MQTTBuffer &buf, MQTTConnackInfo &info)
     {
      info.Init();
      uchar ack_flags;
      if(!buf.ReadByte(ack_flags)) return false;
      if(!buf.ReadByte(info.reason_code)) return false;
      info.session_present = (ack_flags & 0x01) != 0;

      ParseProperties(buf, info);
      return true;
     }

   static bool       DecodePublish(uchar first_byte, MQTTBuffer &buf,
                                    MQTTPublishMessage &msg)
     {
      msg.retain = (first_byte & 0x01) != 0;
      msg.qos = (first_byte >> 1) & 0x03;
      msg.dup = (first_byte & 0x08) != 0;
      msg.packet_id = 0;

      if(!buf.ReadString(msg.topic)) return false;
      if(msg.qos > 0)
        {
         if(!buf.ReadU16(msg.packet_id)) return false;
        }

      bool ok;
      uint props_len = buf.ReadVarInt(ok);
      if(!ok) return false;
      buf.SkipBytes(props_len);

      msg.payload_len = buf.Remaining();
      if(msg.payload_len > 0)
        {
         buf.ReadRawBytes(msg.payload, msg.payload_len);
        }
      else
        {
         ArrayResize(msg.payload, 0);
         msg.payload_len = 0;
        }
      return true;
     }

   static bool       DecodeSuback(MQTTBuffer &buf, ushort &packet_id,
                                   uchar &reason_code)
     {
      if(!buf.ReadU16(packet_id)) return false;

      bool ok;
      uint props_len = buf.ReadVarInt(ok);
      if(!ok) return false;
      buf.SkipBytes(props_len);

      if(!buf.ReadByte(reason_code)) return false;
      return true;
     }

   static bool       DecodePuback(MQTTBuffer &buf, ushort &packet_id,
                                   uchar &reason_code)
     {
      if(!buf.ReadU16(packet_id)) return false;

      if(buf.Remaining() >= 1)
         buf.ReadByte(reason_code);
      else
         reason_code = 0x00;
      return true;
     }

   static bool       DecodePubrec(MQTTBuffer &buf, ushort &packet_id,
                                   uchar &reason_code)
     {
      if(!buf.ReadU16(packet_id)) return false;
      if(buf.Remaining() >= 1)
         buf.ReadByte(reason_code);
      else
         reason_code = 0x00;
      return true;
     }

   static bool       DecodePubrel(MQTTBuffer &buf, ushort &packet_id,
                                   uchar &reason_code)
     {
      if(!buf.ReadU16(packet_id)) return false;
      if(buf.Remaining() >= 1)
         buf.ReadByte(reason_code);
      else
         reason_code = 0x00;
      return true;
     }

   static bool       DecodePubcomp(MQTTBuffer &buf, ushort &packet_id,
                                    uchar &reason_code)
     {
      if(!buf.ReadU16(packet_id)) return false;
      if(buf.Remaining() >= 1)
         buf.ReadByte(reason_code);
      else
         reason_code = 0x00;
      return true;
     }

   static bool       DecodeUnsuback(MQTTBuffer &buf, ushort &packet_id,
                                     uchar &reason_code)
     {
      if(!buf.ReadU16(packet_id)) return false;

      bool ok;
      uint props_len = buf.ReadVarInt(ok);
      if(!ok) return false;
      buf.SkipBytes(props_len);

      if(buf.Remaining() >= 1)
         buf.ReadByte(reason_code);
      else
         reason_code = 0x00;
      return true;
     }

   static bool       IsPingresp(uchar first_byte)
     {
      return (first_byte & 0xF0) == MQTT_PKT_PINGRESP;
     }

   static bool       IsDisconnect(uchar first_byte)
     {
      return (first_byte & 0xF0) == MQTT_PKT_DISCONNECT;
     }
  };

#endif
