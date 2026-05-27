//+------------------------------------------------------------------+
//|                                              MQTTFive/Buffer.mqh  |
//|                    MQTT 5.0 Client Library for MQL5               |
//+------------------------------------------------------------------+
#ifndef _MQTTFIVE_BUFFER_MQH_
#define _MQTTFIVE_BUFFER_MQH_

class MQTTBuffer
  {
private:
   uchar             m_data[];
   uint              m_write_pos;
   uint              m_read_pos;
   uint              m_capacity;

   void              EnsureCapacity(uint additional_bytes)
     {
      uint required = m_write_pos + additional_bytes;
      if(required <= m_capacity)
         return;
      uint new_cap = m_capacity * 2;
      if(new_cap < required)
         new_cap = required;
      ArrayResize(m_data, new_cap);
      m_capacity = new_cap;
     }

public:
                     MQTTBuffer() : m_write_pos(0), m_read_pos(0), m_capacity(4096)
     {
      ArrayResize(m_data, m_capacity);
     }

   void              Reset()
     {
      m_write_pos = 0;
      m_read_pos = 0;
     }

   void              WriteByte(uchar b)
     {
      EnsureCapacity(1);
      m_data[m_write_pos++] = b;
     }

   void              WriteU16(ushort v)
     {
      EnsureCapacity(2);
      m_data[m_write_pos++] = (uchar)(v >> 8);
      m_data[m_write_pos++] = (uchar)(v & 0xFF);
     }

   void              WriteU32(uint v)
     {
      EnsureCapacity(4);
      m_data[m_write_pos++] = (uchar)(v >> 24);
      m_data[m_write_pos++] = (uchar)(v >> 16);
      m_data[m_write_pos++] = (uchar)(v >> 8);
      m_data[m_write_pos++] = (uchar)(v & 0xFF);
     }

   void              WriteVarInt(uint v)
     {
      do
        {
         uchar digit = (uchar)(v % 128);
         v /= 128;
         if(v > 0)
            digit |= 0x80;
         WriteByte(digit);
        }
      while(v > 0);
     }

   void              WriteString(string s)
     {
      uchar temp[];
      int byte_len = StringToCharArray(s, temp, 0, WHOLE_ARRAY, CP_UTF8);
      if(byte_len > 0) byte_len--;
      WriteU16((ushort)byte_len);
      if(byte_len > 0)
         WriteRawBytes(temp, (uint)byte_len);
     }

   void              WriteRawBytes(uchar &src[], uint len)
     {
      if(len == 0)
         return;
      EnsureCapacity(len);
      ArrayCopy(m_data, src, m_write_pos, 0, len);
      m_write_pos += len;
     }

   void              AttachRead(uchar &data[], uint len)
     {
      m_capacity = len;
      ArrayResize(m_data, m_capacity);
      if(len > 0)
         ArrayCopy(m_data, data, 0, 0, len);
      m_read_pos = 0;
      m_write_pos = len;
     }

   uint              Remaining()
     {
      return m_write_pos - m_read_pos;
     }

   bool              ReadByte(uchar &result)
     {
      if(Remaining() < 1)
         return false;
      result = m_data[m_read_pos++];
      return true;
     }

   bool              ReadU16(ushort &result)
     {
      if(Remaining() < 2)
         return false;
      result = (ushort)((m_data[m_read_pos] << 8) | m_data[m_read_pos + 1]);
      m_read_pos += 2;
      return true;
     }

   bool              ReadU32(uint &result)
     {
      if(Remaining() < 4)
         return false;
      result = (m_data[m_read_pos] << 24) | (m_data[m_read_pos + 1] << 16)
             | (m_data[m_read_pos + 2] << 8) | m_data[m_read_pos + 3];
      m_read_pos += 4;
      return true;
     }

   uint              ReadVarInt(bool &ok)
     {
      uint multiplier = 1;
      uint value = 0;
      uchar encoded_byte;
      ok = true;
      do
        {
         if(Remaining() < 1)
           {
            ok = false;
            return 0;
           }
         encoded_byte = m_data[m_read_pos++];
         value += (encoded_byte & 127) * multiplier;
         if(multiplier > 128 * 128 * 128)
           {
            ok = false;
            return 0;
           }
         multiplier *= 128;
        }
      while((encoded_byte & 128) != 0);
      return value;
     }

   bool              ReadString(string &result)
     {
      ushort len;
      if(!ReadU16(len))
         return false;
      if(len == 0)
        {
         result = "";
         return true;
        }
      if(Remaining() < len)
         return false;
      result = CharArrayToString(m_data, m_read_pos, len, CP_UTF8);
      m_read_pos += len;
      return true;
     }

   bool              ReadRawBytes(uchar &result[], uint len)
     {
      if(Remaining() < len)
         return false;
      ArrayResize(result, len);
      ArrayCopy(result, m_data, 0, m_read_pos, len);
      m_read_pos += len;
      return true;
     }

   void              SkipBytes(uint count)
     {
      if(m_read_pos + count <= m_write_pos)
         m_read_pos += count;
     }

   void              GetData(uchar &result[])
     {
      ArrayResize(result, m_write_pos);
      ArrayCopy(result, m_data, 0, 0, m_write_pos);
     }

   uint              WritePosition()
     {
      return m_write_pos;
     }

   uint              ReadPosition()
     {
      return m_read_pos;
     }
  };

#endif
