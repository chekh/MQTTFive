//+------------------------------------------------------------------+
//|                                            MQTTFive/Client.mqh   |
//|                    MQTT 5.0 Client Library for MQL5               |
//+------------------------------------------------------------------+
#ifndef _MQTTFIVE_CLIENT_MQH_
#define _MQTTFIVE_CLIENT_MQH_

#include <MQTTFive/MQTTTypes.mqh>
#include <MQTTFive/MQTTBuffer.mqh>
#include <MQTTFive/MQTTTransport.mqh>
#include <MQTTFive/MQTTCodec.mqh>

typedef void (*MQTTMessageCallback)(string &topic, uchar &payload[], uint payload_len);

class MQTTClient
  {
private:
   MQTTTransport     m_transport;
   MQTTBuffer        m_write_buf;
   MQTTBuffer        m_read_buf;
   ENUM_MQTT_STATE   m_state;
   ushort            m_next_pkt_id;
   datetime          m_last_out;
   datetime          m_last_in;
   ushort            m_keep_alive;
   bool              m_ping_outstanding;
   MQTTMessageCallback m_callback;
   int               m_last_error;
   string            m_last_error_msg;
   bool              m_enableLog;
   MQTTConnackInfo   m_connack_info;
   MQTTInflightMessage m_inflight[];
   MQTTQos2Incoming   m_qos2_incoming[];
   ushort            m_send_quota;
   uint              m_retry_timeout;

   ushort            NextPacketId()
     {
      m_next_pkt_id++;
      if(m_next_pkt_id == 0)
         m_next_pkt_id = 1;
      return m_next_pkt_id;
     }

   void              SetError(int code, string msg)
     {
      m_last_error = code;
      m_last_error_msg = msg;
      if(m_enableLog)
         Print("MQTTFive error: ", msg);
     }

   bool              SendBuffer()
     {
      uchar data[];
      m_write_buf.GetData(data);
      uint len = ArraySize(data);
      if(len == 0)
         return false;
      bool rc = m_transport.Send(data, len);
      if(rc)
        {
         m_last_out = TimeLocal();
         m_last_in = TimeLocal();
        }
      else
         SetError(-1, "Send failed");
      return rc;
     }

   bool              ReadExact(uchar &buffer[], uint count)
     {
      uint total_read = 0;
      while(total_read < count)
        {
         int n = m_transport.Receive(buffer, count - total_read);
         if(n <= 0)
            return false;
         total_read += n;
        }
      return true;
     }

   bool              ReadRawPacket(uchar &first_byte, uint &remaining_len)
     {
      uchar hdr[1];
      if(!ReadExact(hdr, 1))
         return false;
      first_byte = hdr[0];

      remaining_len = 0;
      uint multiplier = 1;
      uchar digit;
      do
        {
         if(!ReadExact(hdr, 1))
            return false;
         digit = hdr[0];
         remaining_len += (digit & 127) * multiplier;
         multiplier *= 128;
         if(multiplier > 128 * 128 * 128)
            return false;
        }
      while((digit & 128) != 0);

       return true;
      }

   int               FindInflight(ushort packet_id)
     {
      for(int i = 0; i < ArraySize(m_inflight); i++)
        {
         if(m_inflight[i].packet_id == packet_id && m_inflight[i].state != MQTT_INFLIGHT_IDLE)
            return i;
        }
      return -1;
     }

   int               AllocInflight()
     {
      for(int i = 0; i < ArraySize(m_inflight); i++)
        {
         if(m_inflight[i].state == MQTT_INFLIGHT_IDLE)
            return i;
        }
      int sz = ArraySize(m_inflight);
      ArrayResize(m_inflight, sz + 1);
      m_inflight[sz].Init();
      return sz;
     }

   void              FreeInflight(int idx)
     {
      m_inflight[idx].state = MQTT_INFLIGHT_IDLE;
      m_inflight[idx].packet_id = 0;
     }

   int               FindQos2Incoming(ushort packet_id)
     {
      for(int i = 0; i < ArraySize(m_qos2_incoming); i++)
        {
         if(m_qos2_incoming[i].packet_id == packet_id)
            return i;
        }
      return -1;
     }

   int               AllocQos2Incoming()
     {
      int sz = ArraySize(m_qos2_incoming);
      ArrayResize(m_qos2_incoming, sz + 1);
      m_qos2_incoming[sz].Init();
      return sz;
     }

   void              FreeQos2Incoming(int idx)
     {
      ArrayRemove(m_qos2_incoming, idx, 1);
     }

    bool              HandleConnack()
     {
      uchar first_byte;
      uint remaining_len;
      if(!ReadRawPacket(first_byte, remaining_len))
        {
         SetError(-1, "Failed to read CONNACK");
         return false;
        }

      uchar body[];
      if(remaining_len > 0)
        {
         ArrayResize(body, remaining_len);
         if(!ReadExact(body, remaining_len))
           {
            SetError(-1, "Incomplete CONNACK body");
            return false;
           }
         m_read_buf.AttachRead(body, remaining_len);
        }
      else
        {
         m_read_buf.Reset();
        }

      m_connack_info.Init();
      if(!MQTTCodec::DecodeConnackFull(m_read_buf, m_connack_info))
        {
         SetError(-1, "Failed to decode CONNACK");
         m_transport.Disconnect();
         return false;
        }

      if(m_connack_info.reason_code != MQTT_CONNACK_SUCCESS)
        {
         SetError(m_connack_info.reason_code,
                  StringFormat("CONNACK rejected, reason code 0x%02X", m_connack_info.reason_code));
         m_transport.Disconnect();
         return false;
        }

      if(m_connack_info.has_server_keep_alive)
         m_keep_alive = m_connack_info.server_keep_alive;

      m_last_in = TimeLocal();
      m_last_out = TimeLocal();
      m_state = MQTT_STATE_CONNECTED;
       m_ping_outstanding = false;
      m_send_quota = m_connack_info.receive_maximum;
      ArrayResize(m_inflight, 0);
      ArrayResize(m_qos2_incoming, 0);
      return true;
     }

   bool              HandleIncomingPacket()
     {
      if(!m_transport.IsReadable())
         return true;

      uchar first_byte;
      uint remaining_len;
      if(!ReadRawPacket(first_byte, remaining_len))
         return true;

      m_last_in = TimeLocal();

      uchar body[];
      if(remaining_len > 0)
        {
         ArrayResize(body, remaining_len);
         if(!ReadExact(body, remaining_len))
           {
            SetError(-1, "Incomplete packet body");
            return false;
           }
         m_read_buf.AttachRead(body, remaining_len);
        }
      else
        {
         m_read_buf.Reset();
        }

      uchar pkt_type = MQTTCodec::PacketType(first_byte);

      if(pkt_type == MQTT_PKT_PUBLISH)
        {
         MQTTPublishMessage msg;
         if(MQTTCodec::DecodePublish(first_byte, m_read_buf, msg))
           {
            if(msg.qos == 0)
              {
               if(m_callback != NULL)
                  m_callback(msg.topic, msg.payload, msg.payload_len);
              }
            else if(msg.qos == 1)
              {
               if(m_callback != NULL)
                  m_callback(msg.topic, msg.payload, msg.payload_len);
               MQTTCodec::EncodePuback(msg.packet_id, m_write_buf);
               SendBuffer();
              }
            else if(msg.qos == 2)
              {
               int idx = AllocQos2Incoming();
               m_qos2_incoming[idx].packet_id = msg.packet_id;
               m_qos2_incoming[idx].topic = msg.topic;
               m_qos2_incoming[idx].payload_len = msg.payload_len;
               ArrayResize(m_qos2_incoming[idx].payload, (int)msg.payload_len);
               if(msg.payload_len > 0)
                  ArrayCopy(m_qos2_incoming[idx].payload, msg.payload, 0, 0, (int)msg.payload_len);
               m_qos2_incoming[idx].retain = msg.retain;
               m_qos2_incoming[idx].dup = msg.dup;
               MQTTCodec::EncodePubrec(msg.packet_id, m_write_buf);
               SendBuffer();
              }
           }
        }
      else if(pkt_type == MQTT_PKT_PUBREC)
        {
         ushort pkt_id;
         uchar reason;
         if(MQTTCodec::DecodePubrec(m_read_buf, pkt_id, reason))
           {
            int idx = FindInflight(pkt_id);
            if(idx >= 0 && m_inflight[idx].state == MQTT_INFLIGHT_PUBREC)
              {
               m_inflight[idx].state = MQTT_INFLIGHT_PUBREL;
               MQTTCodec::EncodePubrel(pkt_id, m_write_buf);
               SendBuffer();
              }
           }
        }
      else if(pkt_type == MQTT_PKT_PUBREL)
        {
         ushort pkt_id;
         uchar reason;
         if(MQTTCodec::DecodePubrel(m_read_buf, pkt_id, reason))
           {
            int idx = FindQos2Incoming(pkt_id);
            if(idx >= 0)
              {
               if(m_callback != NULL)
                  m_callback(m_qos2_incoming[idx].topic,
                             m_qos2_incoming[idx].payload,
                             m_qos2_incoming[idx].payload_len);
               MQTTCodec::EncodePubcomp(pkt_id, m_write_buf);
               SendBuffer();
               FreeQos2Incoming(idx);
              }
           }
        }
      else if(pkt_type == MQTT_PKT_PUBCOMP)
        {
         ushort pkt_id;
         uchar reason;
         if(MQTTCodec::DecodePubcomp(m_read_buf, pkt_id, reason))
           {
            int idx = FindInflight(pkt_id);
            if(idx >= 0)
              {
               FreeInflight(idx);
               m_send_quota++;
              }
           }
        }
      else if(MQTTCodec::IsPingresp(first_byte))
        {
         m_ping_outstanding = false;
        }
      else if(pkt_type == MQTT_PKT_SUBACK)
        {
         ushort pkt_id;
         uchar reason;
         MQTTCodec::DecodeSuback(m_read_buf, pkt_id, reason);
        }
      else if(pkt_type == MQTT_PKT_PUBACK)
        {
         ushort pkt_id;
         uchar reason;
         if(MQTTCodec::DecodePuback(m_read_buf, pkt_id, reason))
           {
            int idx = FindInflight(pkt_id);
            if(idx >= 0)
              {
               FreeInflight(idx);
               m_send_quota++;
              }
           }
        }
      else if(pkt_type == MQTT_PKT_UNSUBACK)
        {
         ushort pkt_id;
         uchar reason;
         MQTTCodec::DecodeUnsuback(m_read_buf, pkt_id, reason);
        }
      else if(MQTTCodec::IsDisconnect(first_byte))
        {
         SetError(-1, "Server sent DISCONNECT");
         m_state = MQTT_STATE_DISCONNECTED;
         return false;
        }

      return true;
     }

public:
                      MQTTClient() : m_state(MQTT_STATE_DISCONNECTED),
                       m_next_pkt_id(0), m_last_out(0), m_last_in(0),
                       m_keep_alive(60), m_ping_outstanding(false),
                       m_callback(NULL), m_last_error(0), m_last_error_msg(""),
                        m_enableLog(false), m_connack_info(),
                        m_send_quota(65535), m_retry_timeout(20)
       {
       }

                     ~MQTTClient()
     {
      Disconnect();
     }

   void              SetCallback(MQTTMessageCallback callback)
     {
      m_callback = callback;
     }

   void              SetKeepAlive(ushort seconds)
     {
      m_keep_alive = seconds;
     }

    void              SetLog(bool enable)
      {
       m_enableLog = enable;
      }

   MQTTConnackInfo    GetConnackInfo()
     {
      return m_connack_info;
     }

   bool              Connect(string host, ushort port, MQTTConnectParams &params,
                              bool useTLS = false, uint timeout = 15)
     {
      Disconnect();

      m_keep_alive = params.keep_alive;
      m_transport.SetLog(m_enableLog);

      if(!m_transport.Connect(host, port, timeout, useTLS))
        {
         SetError(-1, "Transport connect failed");
         return false;
        }

      MQTTCodec::EncodeConnect(params, m_write_buf);
      if(!SendBuffer())
        {
         SetError(-1, "Send CONNECT failed");
         return false;
        }

      if(!HandleConnack())
         return false;

      return true;
     }

    bool              Disconnect()
      {
       if(m_state == MQTT_STATE_CONNECTED)
         {
          MQTTCodec::EncodeDisconnect(m_write_buf);
          SendBuffer();
         }
       m_transport.Disconnect();
       m_state = MQTT_STATE_DISCONNECTED;
       return true;
      }

   bool              Disconnect(uchar reason_code, uint session_expiry = 0)
     {
      if(m_state == MQTT_STATE_CONNECTED)
        {
         MQTTCodec::EncodeDisconnectWithReason(reason_code, session_expiry, m_write_buf);
         SendBuffer();
        }
      m_transport.Disconnect();
      m_state = MQTT_STATE_DISCONNECTED;
      return true;
     }

   bool              Publish(string topic, string payload, uchar qos = 0,
                              bool retain = false)
     {
      if(m_state != MQTT_STATE_CONNECTED)
        {
         SetError(-1, "Not connected");
         return false;
        }
       ushort pkt_id = (qos > 0) ? NextPacketId() : 0;
       MQTTCodec::EncodePublishString(topic, payload, qos, retain, pkt_id, m_write_buf);
      if(qos > 0)
        {
         if(m_send_quota == 0)
           {
            SetError(-1, "Send quota exceeded");
            return false;
           }
         int idx = AllocInflight();
         m_inflight[idx].packet_id = pkt_id;
         m_inflight[idx].qos = qos;
         m_inflight[idx].state = (qos == 1) ? MQTT_INFLIGHT_PUBACK : MQTT_INFLIGHT_PUBREC;
         m_inflight[idx].topic = topic;
         m_inflight[idx].retain = retain;
         m_inflight[idx].sent_time = TimeLocal();
         m_inflight[idx].pub_flags = 0;
         if(qos == 1) m_inflight[idx].pub_flags |= MQTT_PUB_FLAG_QOS1;
         if(qos == 2) m_inflight[idx].pub_flags |= MQTT_PUB_FLAG_QOS2;
         if(retain) m_inflight[idx].pub_flags |= MQTT_PUB_FLAG_RETAIN;
         m_inflight[idx].payload_len = 0;
         m_send_quota--;
        }
       return SendBuffer();
     }

   bool              Publish(string topic, uchar &payload[], uint payload_len,
                              uchar qos = 0, bool retain = false)
     {
      if(m_state != MQTT_STATE_CONNECTED)
        {
         SetError(-1, "Not connected");
         return false;
        }
       ushort pkt_id = (qos > 0) ? NextPacketId() : 0;
       MQTTCodec::EncodePublish(topic, payload, payload_len, qos, retain, pkt_id, m_write_buf);
      if(qos > 0)
        {
         if(m_send_quota == 0)
           {
            SetError(-1, "Send quota exceeded");
            return false;
           }
         int idx = AllocInflight();
         m_inflight[idx].packet_id = pkt_id;
         m_inflight[idx].qos = qos;
         m_inflight[idx].state = (qos == 1) ? MQTT_INFLIGHT_PUBACK : MQTT_INFLIGHT_PUBREC;
         m_inflight[idx].topic = topic;
         m_inflight[idx].retain = retain;
         m_inflight[idx].sent_time = TimeLocal();
         m_inflight[idx].pub_flags = 0;
         if(qos == 1) m_inflight[idx].pub_flags |= MQTT_PUB_FLAG_QOS1;
         if(qos == 2) m_inflight[idx].pub_flags |= MQTT_PUB_FLAG_QOS2;
         if(retain) m_inflight[idx].pub_flags |= MQTT_PUB_FLAG_RETAIN;
         m_inflight[idx].payload_len = payload_len;
         ArrayResize(m_inflight[idx].payload, (int)payload_len);
         ArrayCopy(m_inflight[idx].payload, payload, 0, 0, (int)payload_len);
         m_send_quota--;
        }
       return SendBuffer();
     }

    bool              Subscribe(string topic, uchar qos = 0)
      {
       if(m_state != MQTT_STATE_CONNECTED)
         {
          SetError(-1, "Not connected");
          return false;
         }
       MQTTSubscribeParams params;
       params.Init();
       params.topic_filter = topic;
       params.options.maximum_qos = qos;
       MQTTCodec::EncodeSubscribe(NextPacketId(), params, m_write_buf);
       return SendBuffer();
      }

   bool              Subscribe(MQTTSubscribeParams &params)
     {
      if(m_state != MQTT_STATE_CONNECTED)
        {
         SetError(-1, "Not connected");
         return false;
        }
      MQTTCodec::EncodeSubscribe(NextPacketId(), params, m_write_buf);
      return SendBuffer();
     }

   bool              Unsubscribe(string topic)
     {
      if(m_state != MQTT_STATE_CONNECTED)
        {
         SetError(-1, "Not connected");
         return false;
        }
      MQTTCodec::EncodeUnsubscribe(NextPacketId(), topic, m_write_buf);
      return SendBuffer();
     }

   bool              Loop()
     {
      if(m_state != MQTT_STATE_CONNECTED)
         return false;

      if(!m_transport.IsConnected())
        {
         SetError(-1, "Connection lost");
         m_state = MQTT_STATE_DISCONNECTED;
         return false;
        }

      datetime now = TimeLocal();
      if(m_keep_alive > 0)
        {
         if((now - m_last_out) >= m_keep_alive)
           {
            if(m_ping_outstanding)
              {
               SetError(-1, "Keepalive timeout (no PINGRESP)");
               m_state = MQTT_STATE_DISCONNECTED;
               m_transport.Disconnect();
               return false;
              }
            MQTTCodec::EncodePingreq(m_write_buf);
            if(!SendBuffer())
               return false;
            m_ping_outstanding = true;
           }
         if((now - m_last_in) >= (m_keep_alive * 3 / 2))
           {
            SetError(-1, "Keepalive timeout (no data received)");
            m_state = MQTT_STATE_DISCONNECTED;
            m_transport.Disconnect();
            return false;
           }
         }

      if(m_retry_timeout > 0)
        {
         datetime now_retry = TimeLocal();
         for(int i = 0; i < ArraySize(m_inflight); i++)
           {
            if(m_inflight[i].state == MQTT_INFLIGHT_IDLE)
               continue;
            if((uint)(now_retry - m_inflight[i].sent_time) < m_retry_timeout)
               continue;
            if(m_inflight[i].qos == 1 && m_inflight[i].state == MQTT_INFLIGHT_PUBACK)
              {
               MQTTCodec::EncodePublish(m_inflight[i].topic,
                  m_inflight[i].payload, m_inflight[i].payload_len,
                  1, m_inflight[i].retain, m_inflight[i].packet_id, m_write_buf);
               SendBuffer();
               m_inflight[i].sent_time = now_retry;
              }
            else if(m_inflight[i].qos == 2 && m_inflight[i].state == MQTT_INFLIGHT_PUBREC)
              {
               MQTTCodec::EncodePublish(m_inflight[i].topic,
                  m_inflight[i].payload, m_inflight[i].payload_len,
                  2, m_inflight[i].retain, m_inflight[i].packet_id, m_write_buf);
               SendBuffer();
               m_inflight[i].sent_time = now_retry;
              }
            else if(m_inflight[i].state == MQTT_INFLIGHT_PUBREL)
              {
               MQTTCodec::EncodePubrel(m_inflight[i].packet_id, m_write_buf);
               SendBuffer();
               m_inflight[i].sent_time = now_retry;
              }
           }
        }

       return HandleIncomingPacket();
     }

   bool              IsConnected()
     {
      return m_state == MQTT_STATE_CONNECTED;
     }

   string            GetLastError()
     {
      return m_last_error_msg;
     }

   int               GetLastErrorCode()
     {
      return m_last_error;
     }
  };

#endif
