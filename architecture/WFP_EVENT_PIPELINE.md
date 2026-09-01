# WFP event pipeline

## Native side

`FwpmEngineOpen0` -> `FwpmNetEventSubscribe1` -> `FWPM_NET_EVENT2` callback -> fixed-width `FlyDpiEventSnapshot`.

The Windows SDK structure is never exposed to Go. The snapshot contains only scalar fields that are stable across the C ABI boundary.

`FWPM_NET_EVENT_HEADER2.timeStamp` is a `FILETIME` value, not a pointer. The native adapter serializes its 64-bit value as two 32-bit fields. `FWPM_NET_EVENT2.type` identifies the event. For classify-drop events, `classifyDrop->msFwpResult` is the per-event result code. citeturn520340search1turn424175search1

## Correlation

The observer is not itself a censorship detector. A reset, timeout, or block classification must be correlated with an application-level probe and a target tuple. In particular, a non-zero WFP result does not by itself prove forged RST injection.

## Data flow

```text
FWPM_NET_EVENT2
      |
      v
FlyDpiEventSnapshot
      |
      v
Go DecodeSnapshot
      |
      v
Telemetry Event
      |
      +--> probe correlation
      |
      +--> DNS consistency
      |
      +--> classifier
```

## Current limitation

The native callback keeps only the latest snapshot. Production telemetry should replace that slot with a bounded lock-protected ring buffer and explicit overflow accounting so short bursts are not silently lost.
