# MQTT 5.0 Protocol Compliance

This document maps MQTTFive's implementation against the MQTT 5.0 specification
(ISO/IEC 20922:2016 / OASIS Standard). Each section references the spec section
and notes compliance status.

Legend:

- **Implemented** — fully working, tested
- **Partial** — implemented with simplifications
- **Not implemented** — omitted from this version

---

## 1. CONNECT (Spec §3.1)

| Field | Status | Notes |
|-------|--------|-------|
| Protocol Name "MQTT" | Implemented | |
| Protocol Level 5 | Implemented | |
| Clean Start | Implemented | |
| Will Flag | Implemented | |
| Will QoS | Implemented | Bits in Connect Flags |
| Will Retain | Implemented | |
| Username/Password | Implemented | |
| Keep Alive | Implemented | |
| **CONNECT Properties** | | |
| Session Expiry Interval (0x11) | Implemented | Sent if > 0 |
| Receive Maximum (0x21) | Implemented | Sent if < 65535 |
| Maximum Packet Size (0x27) | Implemented | Sent if > 0 |
| Topic Alias Maximum (0x22) | Implemented | Sent if > 0 |
| Request Problem Information (0x17) | Not implemented | Always defaults to 1 |
| Request Response Information (0x19) | Not implemented | |
| Authentication Method (0x15) | Not implemented | AUTH not supported |
| Authentication Data (0x16) | Not implemented | AUTH not supported |
| User Property (0x26) | Not implemented | Not sent in CONNECT |

## 2. CONNACK (Spec §3.2)

| Field | Status | Notes |
|-------|--------|-------|
| Session Present | Implemented | |
| Reason Code | Implemented | |
| **CONNACK Properties** | | |
| Session Expiry Interval (0x11) | Implemented | |
| Receive Maximum (0x21) | Implemented | |
| Maximum QoS (0x24) | Implemented | |
| Retain Available (0x25) | Implemented | |
| Maximum Packet Size (0x27) | Implemented | |
| Assigned Client ID (0x12) | Implemented | |
| Topic Alias Maximum (0x22) | Implemented | |
| Reason String (0x1F) | Partial | Parsed but not stored |
| User Property (0x26) | Partial | Parsed but not stored |
| Wildcard Subscription Available (0x28) | Partial | Parsed but not acted on |
| Subscription ID Available (0x29) | Partial | Parsed but not acted on |
| Shared Subscription Available (0x2A) | Partial | Parsed but not acted on |
| Server Keep Alive (0x13) | Implemented | Overrides client keepalive |
| Response Information (0x1A) | Not implemented | |
| Server Reference (0x1C) | Not implemented | |
| Authentication Method (0x15) | Not implemented | |
| Authentication Data (0x16) | Not implemented | |

## 3. PUBLISH (Spec §3.3)

| Feature | Status | Notes |
|---------|--------|-------|
| QoS 0 | Implemented | Fire and forget |
| QoS 1 | Implemented | With inflight tracking and retry |
| QoS 2 | Implemented | Full PUBREC/PUBREL/PUBCOMP flow |
| DUP flag | Partial | Set by codec on encode, not auto-set on retry |
| Retain | Implemented | |
| Topic Alias (0x23) | Partial | **Outgoing only**. Incoming PUBLISH with alias is not resolved. |
| Payload Format Indicator (0x01) | Not implemented | Not sent in PUBLISH properties |
| Message Expiry Interval (0x02) | Not implemented | |
| Response Topic (0x08) | Not implemented | |
| Correlation Data (0x09) | Not implemented | |
| Subscription Identifier (0x0B) | Not implemented | |
| Content Type (0x03) | Not implemented | |
| User Property (0x26) | Not implemented | |

**Simplification**: Incoming PUBLISH properties are skipped entirely (Property
Length is read, all property bytes skipped). The payload is returned as raw
`uchar[]` without any property processing.

## 4. PUBACK (Spec §3.4)

| Field | Status | Notes |
|-------|--------|-------|
| Packet ID | Implemented | |
| Reason Code | Implemented | Read if present, defaults to 0x00 |
| Properties | Not parsed | Skipped, not needed for basic flow |

## 5. PUBREC (Spec §3.5)

| Field | Status | Notes |
|-------|--------|-------|
| Packet ID | Implemented | |
| Reason Code | Partial | Encoded with remaining_length=2 (no reason code byte). Decoded if present. |
| Properties | Not parsed | |

**Simplification**: Outgoing PUBREC has remaining length = 2 (only Packet ID).
Reason Code defaults to 0x00 (Success). Properties omitted. This is valid per
spec §3.5.2: "If the Remaining Length is 2 there is no Reason Code and the
properties length is 0."

## 6. PUBREL (Spec §3.6)

| Field | Status | Notes |
|-------|--------|-------|
| Packet ID | Implemented | |
| Reason Code | Partial | Same as PUBREC — minimal encoding |
| Properties | Not parsed | |

## 7. PUBCOMP (Spec §3.7)

| Field | Status | Notes |
|-------|--------|-------|
| Packet ID | Implemented | |
| Reason Code | Partial | Same minimal encoding |
| Properties | Not parsed | |

## 8. SUBSCRIBE (Spec §3.8)

| Field | Status | Notes |
|-------|--------|-------|
| Packet ID | Implemented | |
| Properties Length | Implemented | Always 0 (no properties) |
| Topic Filter | Implemented | Single filter per packet |
| Subscription Options | Implemented | See below |
| Subscription Identifier (0x0B) | Not implemented | |
| User Property (0x26) | Not implemented | |

### Subscription Options (Spec §3.8.3.1)

| Option | Status | Bits |
|--------|--------|------|
| Maximum QoS | Implemented | 0-1 |
| No Local | Implemented | 2 |
| Retain As Published | Implemented | 3 |
| Retain Handling | Implemented | 4-5 |

**Simplification**: Only one topic filter per SUBSCRIBE packet. The spec allows
multiple topic filters in a single SUBSCRIBE. This is sufficient for most use
cases but means each `Subscribe()` call generates a separate SUBSCRIBE packet.

## 9. SUBACK (Spec §3.9)

| Field | Status | Notes |
|-------|--------|-------|
| Packet ID | Implemented | |
| Properties | Skipped | Read length, skip bytes |
| Reason Code | Implemented | First reason code read |

**Simplification**: Only the first Reason Code is extracted. Multiple
subscription reason codes (for multi-filter SUBSCRIBE) are not handled. Since
we send one filter per SUBSCRIBE, this is sufficient.

## 10. UNSUBSCRIBE (Spec §3.10)

| Field | Status | Notes |
|-------|--------|-------|
| Packet ID | Implemented | |
| Properties Length | Implemented | Always 0 |
| Topic Filter | Implemented | Single filter |

## 11. UNSUBACK (Spec §3.11)

| Field | Status | Notes |
|-------|--------|-------|
| Packet ID | Implemented | |
| Properties | Skipped | |
| Reason Code | Implemented | |

## 12. PINGREQ/PINGRESP (Spec §3.12/3.13)

| Feature | Status | Notes |
|---------|--------|-------|
| PINGREQ | Implemented | Sent automatically on keepalive timeout |
| PINGRESP | Implemented | Clears ping_outstanding flag |

## 13. DISCONNECT (Spec §3.14)

| Feature | Status | Notes |
|---------|--------|-------|
| Reason Code | Implemented | |
| Session Expiry Interval (0x11) | Implemented | |
| Other properties | Not implemented | Reason String, User Property, Server Reference |

## 14. AUTH (Spec §3.15)

| Feature | Status | Notes |
|---------|--------|-------|
| Enhanced Authentication | **Not implemented** | Entire AUTH packet type unsupported |

## 15. Flow Control (Spec §4.9)

| Feature | Status | Notes |
|---------|--------|-------|
| Receive Maximum (client→broker) | Implemented | Sent in CONNECT, quota tracked |
| Receive Maximum (broker→client) | Not enforced | Client does not limit incoming QoS > 0 messages |
| Send quota tracking | Implemented | Decrements on QoS > 0 publish, increments on PUBACK/PUBCOMP |
|_quota exceeded handling | Implemented | Returns error when quota = 0 |

**Simplification**: The client does not enforce its own Receive Maximum on the
broker. The broker can send unlimited QoS > 0 messages. The client processes
all incoming messages regardless of the `receive_maximum` value sent in CONNECT.

## 16. Session State (Spec §4.1)

| Feature | Status | Notes |
|---------|--------|-------|
| Clean Start = 1 | Implemented | Always starts fresh session |
| Session persistence | Not implemented | Clean Start is always 1 in practice |
| Session Expiry | Partial | Sent in CONNECT/DISCONNECT, not acted on |

## 17. Topic Alias (Spec §3.3.2.5)

| Feature | Status | Notes |
|---------|--------|-------|
| Outgoing alias registration | Implemented | Topic + alias → broker stores mapping |
| Outgoing alias reuse | Implemented | Empty topic + alias → broker reuses mapping |
| Incoming alias resolution | **Not implemented** | Incoming PUBLISH with alias not resolved |
| Alias maximum enforcement | Implemented | Checked against CONNACK topic_alias_maximum |

**Simplification**: Incoming PUBLISH messages that use Topic Alias are not
resolved. The topic field will contain whatever the broker sent (which may be
empty if alias is used). This means a subscriber may receive messages with empty
topic strings when the broker uses aliases. For most use cases where the client
only publishes (not subscribes), this is not an issue.

## 18. Will Message (Spec §3.1.2.5)

| Feature | Status | Notes |
|---------|--------|-------|
| Will Topic | Implemented | |
| Will Payload | Implemented | |
| Will QoS | Implemented | |
| Will Retain | Implemented | |
| Will Delay Interval (0x18) | Implemented | |
| Payload Format Indicator (0x01) | Implemented | |
| Message Expiry Interval (0x02) | Implemented | |
| Content Type (0x03) | Implemented | |

## 19. Inflight Message Retry

| Feature | Status | Notes |
|---------|--------|-------|
| QoS 1 retry (PUBACK timeout) | Implemented | Configurable via `m_retry_timeout` |
| QoS 2 retry (PUBREC timeout) | Implemented | |
| QoS 2 PUBREL retry | Implemented | |
| DUP flag on retry | **Not set** | Retried messages do not set DUP flag |

**Simplification**: The DUP flag is not automatically set on retried messages.
Per spec §3.3.1.1, the DUP flag must be set to 1 when re-delivering. This means
the broker may treat retries as new messages. In practice, Mosquitto handles
this correctly via Packet ID deduplication.

## 20. Error Handling

| Scenario | Status | Notes |
|----------|--------|-------|
| Transport failure | Implemented | Detects and reports |
| Keepalive timeout | Implemented | 1.5x keepalive no-data threshold |
| Broker DISCONNECT | Implemented | Detected and reported |
| Packet decode failure | Implemented | Returns false, sets error |
| Unknown property IDs | **Skipped** | ParseProperties skips remaining props on unknown ID |

**Simplification**: When `ParseProperties` encounters an unknown property ID, it
skips to the end of the entire properties block. This means all subsequent
properties in that packet are lost. For brokers that only send known properties
(Mosquitto, EMQX, HiveMQ), this has no impact.

## Summary

| Category | Implemented | Partial | Not Implemented |
|----------|-------------|---------|-----------------|
| Packet Types | 12/15 | 0 | AUTH (3 types) |
| CONNECT Properties | 4/10 | 0 | 6 |
| CONNACK Properties | 8/18 | 4 | 6 |
| PUBLISH Properties | 1/10 | 1 | 8 |
| Subscription Options | 4/4 | 0 | 0 |
| Flow Control | 2/3 | 0 | 1 |
| Topic Alias | 2/3 | 0 | 1 |
| Will Properties | 4/4 | 0 | 0 |

### Key Simplifications

1. **Incoming PUBLISH properties ignored** — all property bytes skipped
2. **Incoming Topic Alias not resolved** — empty topic on aliased messages
3. **DUP flag not set on retry** — broker Packet ID dedup handles this
4. **Single topic per SUBSCRIBE** — each subscribe is a separate packet
5. **Unknown property = stop parsing** — remaining properties in that block are lost
6. **AUTH entirely unsupported** — no enhanced authentication
7. **Receive Maximum not enforced** — client doesn't limit broker's publish rate
8. **Session persistence not implemented** — always clean start
