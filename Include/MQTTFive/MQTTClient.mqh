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

      uchar reason_code = 0xFF;
      bool session_present = false;
      MQTTCodec::DecodeConnack(m_read_buf, reason_code, session_present);

      if(reason_code != MQTT_CONNACK_SUCCESS)
        {
         SetError(reason_code,
                  StringFormat("CONNACK rejected, reason code 0x%02X", reason_code));
         m_transport.Disconnect();
         return false;
        }

      m_last_in = TimeLocal();
      m_last_out = TimeLocal();
      m_state = MQTT_STATE_CONNECTED;
      m_ping_outstanding = false;
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
            if(m_callback != NULL)
               m_callback(msg.topic, msg.payload, msg.payload_len);
            if(msg.qos == 1)
              {
               MQTTCodec::EncodePuback(msg.packet_id, m_write_buf);
               SendBuffer();
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
         MQTTCodec::DecodePuback(m_read_buf, pkt_id, reason);
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
                      m_enableLog(false)
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
      params.topic_filter = topic;
      params.qos = qos;
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
