# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] — 2026-07-21

### Added

- `MQTTPublishProperties` struct — supports Message Expiry Interval,
  Topic Alias, Payload Format Indicator (MQTT 5.0 Section 3.3.2).
- `Publish(topic, payload, qos, retain, MQTTPublishProperties &props)` —
  new overload for publishing with properties.
- `EncodePublishStringWithProps` in MQTTCodec — encodes PUBLISH packet
  with full properties bag.
- `CleanupState()` method in MQTTClient — resets inflight/QoS2/alias state
  between sessions. Called from Disconnect (2 overloads) and ForceDisconnect;
  NOT from Connect (to preserve state for session resume with clean_start=false).
- `TestT16_PublishProperties.mq5` — 7 assertions for PUBLISH properties.

### Fixed

- `Receive()` buffer handling — use temporary array instead of array slice
  (MQL5 doesn't support slices). Was broken in upstream since 1.0.0.
- `ReadRawPacket()` returns false on read failure (was incorrectly `true`,
  masking connection errors).

## [1.0.0] — 2026-05-27

### Added

- MQTT v5.0 protocol (Protocol Version = 0x05)
- TCP + TLS via native MQL5 Socket API
- QoS 0, 1, 2 with inflight tracking and auto-retry
- CONNECT with properties: session expiry, receive maximum, topic alias maximum, max packet size
- CONNACK parsing: receive maximum, maximum QoS, retain available, topic alias maximum, server keep alive, assigned client ID, session expiry, maximum packet size
- Will messages with properties: will delay interval, payload format indicator, message expiry, content type
- Topic Alias for outgoing PUBLISH (register + reuse)
- Flow Control: Receive Maximum enforcement, send quota tracking
- Subscription Options: maximum QoS, no local, retain as published, retain handling
- DISCONNECT with reason code + session expiry interval
- Keepalive with automatic PINGREQ/PINGRESP
- Binary-safe payload (`uchar[]`)
- UTF-8 string support via `CP_UTF8`
- `ForceDisconnect()` for abnormal TCP close (triggers Will message)
- 15 focused test scripts (T01–T15), all passing against Mosquitto 5.0
- MIT License
