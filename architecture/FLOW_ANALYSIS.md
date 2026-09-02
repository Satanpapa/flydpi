# FlyDPI Flow / Session Analysis

The flow analyzer sits above normalized packet metadata and passive transport parsers.

```text
WFP event / packet metadata
        |
        v
   FlowKey + flags
        |
        v
+---------------------+
| FlowSessionAnalyzer |
+----------+----------+
           |
     +-----+-----+
     |           |
     v           v
 TCP lifecycle  TLS/QUIC metadata
     |           |
     +-----+-----+
           v
      FlowSnapshot
           |
           v
        classifier
```

## TCP lifecycle

The analyzer tracks SYN, SYN-ACK, ACK, FIN and RST observations. It derives a compact lifecycle state without treating a single signal as proof of censorship or interference.

`IdleTimeoutSuspected` is emitted only when an incomplete SYN path remains idle beyond the configured diagnostic timeout.

## TLS/QUIC

The transport parser is passive. A detected TLS ClientHello may carry an SNI value; a detected QUIC long header carries version, packet type and connection-ID lengths. These observations are evidence, not verdicts.

## Correlation

A future evidence layer should correlate:

- flow lifecycle;
- reset/drop-like WFP events;
- DNS anomalies;
- TLS ClientHello/SNI observations;
- QUIC Initial/long-header observations;
- application/process identity where Windows supplies it.

No single signal is interpreted as a definitive DPI finding.

## Memory and cleanup

The flow table is bounded operationally by idle expiration. Maintenance should run periodically and remove flows that have not been observed for the configured idle interval.

## Non-goals

This layer does not rewrite TLS, alter HTTP headers, change TCP sequence numbers, synthesize QUIC packets, inject traffic, or execute censorship-evasion policies.
