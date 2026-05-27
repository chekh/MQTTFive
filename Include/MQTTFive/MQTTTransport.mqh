//+------------------------------------------------------------------+
//|                                          MQTTFive/Transport.mqh  |
//|                    MQTT 5.0 Client Library for MQL5               |
//+------------------------------------------------------------------+
#ifndef _MQTTFIVE_TRANSPORT_MQH_
#define _MQTTFIVE_TRANSPORT_MQH_

class MQTTTransport
  {
private:
   int               m_socket;
   string            m_host;
   ushort            m_port;
   bool              m_useTLS;
   uint              m_timeout;
   bool              m_enableLog;

public:
                     MQTTTransport() : m_socket(INVALID_HANDLE), m_host(""),
                      m_port(0), m_useTLS(false), m_timeout(15), m_enableLog(false)
     {
     }

                     ~MQTTTransport()
     {
      Disconnect();
     }

   void              SetLog(bool enable)
     {
      m_enableLog = enable;
     }

   bool              Connect(string host, ushort port, uint timeout_sec, bool useTLS)
     {
      if(m_socket > 0 && SocketIsConnected(m_socket))
         return true;

      m_host = host;
      m_port = port;
      m_useTLS = useTLS;
      m_timeout = timeout_sec;

      m_socket = SocketCreate();
      if(m_socket == INVALID_HANDLE)
        {
         if(m_enableLog)
            Print("MQTTFive: socket create failed, error ", GetLastError());
         return false;
        }

      if(!SocketConnect(m_socket, m_host, m_port, m_timeout))
        {
         if(m_enableLog)
            Print("MQTTFive: connect failed to ", m_host, ":", m_port,
                  ", error ", GetLastError());
         SocketClose(m_socket);
         m_socket = INVALID_HANDLE;
         return false;
        }

      if(m_useTLS)
        {
         if(!SocketTlsHandshake(m_socket, m_host))
           {
            if(m_enableLog)
               Print("MQTTFive: TLS handshake failed");
            SocketClose(m_socket);
            m_socket = INVALID_HANDLE;
            return false;
           }
        }

      return true;
     }

   bool              Disconnect()
     {
      if(m_socket > 0)
        {
         SocketClose(m_socket);
         m_socket = INVALID_HANDLE;
        }
      return true;
     }

   bool              Send(uchar &data[], uint len)
     {
      if(m_socket <= 0)
         return false;
      bool rc;
      if(m_useTLS)
         rc = SocketTlsSend(m_socket, data, len);
      else
         rc = SocketSend(m_socket, data, len);
      return rc;
     }

   int               Receive(uchar &data[], uint max_len)
     {
      if(m_socket <= 0)
         return -1;
      int numBytes;
      if(m_useTLS)
         numBytes = SocketTlsRead(m_socket, data, max_len);
      else
         numBytes = SocketRead(m_socket, data, max_len, m_timeout);
      return numBytes;
     }

   bool              IsConnected()
     {
      if(m_socket <= 0)
         return false;
      return SocketIsConnected(m_socket);
     }

   bool              IsReadable()
     {
      if(m_socket <= 0)
         return false;
      return SocketIsReadable(m_socket);
     }

   int               GetSocket()
     {
      return m_socket;
     }
  };

#endif
