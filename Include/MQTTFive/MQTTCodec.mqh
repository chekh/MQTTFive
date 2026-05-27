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
         flags |= (params.will_qos << 3);
         if(params.will_retain) flags |= MQTT_FLAG_WILL_RETAIN;
        }
      if(params.username != "")
        {
         flags |= MQTT_FLAG_USERNAME;
         if(params.password != "") flags |= MQTT_FLAG_PASSWORD;
        }
      buf.WriteByte(flags);
      buf.WriteU16(params.keep_alive);
      buf.WriteByte(0x00);

      buf.WriteString(params.client_id);
      if(params.will_topic != "")
        {
         buf.WriteByte(0x00);
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
                                          MQTTBuffer &out)
     {
      MQTTBuffer buf;
      buf.WriteString(topic);
      if(qos > 0)
         buf.WriteU16(packet_id);
      buf.WriteByte(0x00);
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
                                    MQTTBuffer &out)
     {
      MQTTBuffer buf;
      buf.WriteString(topic);
      if(qos > 0)
         buf.WriteU16(packet_id);
      buf.WriteByte(0x00);
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
      buf.WriteByte((uchar)(params.qos & 0x03));

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

   static uchar      PacketType(uchar first_byte)
     {
      return first_byte & 0xF0;
     }

   static bool       DecodeConnack(MQTTBuffer &buf, uchar &reason_code,
                                    bool &session_present)
     {
      uchar ack_flags;
      if(!buf.ReadByte(ack_flags)) return false;
      if(!buf.ReadByte(reason_code)) return false;
      session_present = (ack_flags & 0x01) != 0;

      bool ok;
      uint props_len = buf.ReadVarInt(ok);
      if(!ok) return false;
      buf.SkipBytes(props_len);
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
