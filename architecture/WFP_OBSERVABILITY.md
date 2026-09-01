# WFP Observability Layer

## Why this layer exists

FlyDPI needs an evidence pipeline before any active traffic policy is considered. Windows Filtering Platform exposes a user-mode filter-engine session through `FwpmEngineOpen0`; dynamic sessions remove objects created in the session when it ends. Windows 8+ also exposes `FwpmNetEventSubscribe1` for asynchronous network-event notifications. These APIs are used here only for observation and lifecycle management. [Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/api/fwpmu/nf-fwpmu-fwpmengineopen0)

## Current implementation

`native/wfp-observer/` contains a small C++ ABI boundary:

```text
Go / Rust
   |
   | C ABI
   v
FlyDpiWfpObserver
   |
   +--> FwpmEngineOpen0(dynamic session)
   |
   +--> FwpmNetEventSubscribe1(callback)
   |
   +--> event counter / future event adapter
   |
   +--> FwpmNetEventUnsubscribe0
   |
   +--> FwpmEngineClose0
```

The callback currently counts events only. This is deliberate: parsing or exporting event payloads is a separate boundary and should preserve a small, stable telemetry schema.

## Event normalization target

The next adapter should translate Windows net-events into the Rust model without leaking Windows ABI types above the native boundary:

```text
NetworkEvent {
  timestamp_unix_ms: u64,
  protocol: Tcp | Udp | Other,
  direction: Inbound | Outbound | Unknown,
  local_addr: Option<IpAddress>,
  remote_addr: Option<IpAddress>,
  local_port: Option<u16>,
  remote_port: Option<u16>,
  pid: Option<u32>,
  app_id: Option<String>,
  event_code: u32,
  status: Option<u32>,
}
```

Only fields present in the Windows event are populated. Missing fields remain `None`; they are never inferred as a failure.

## Threading and lifetime rules

1. `FlyDpiWfpObserver` owns both WFP handles.
2. The callback receives only a pointer to the observer context; it must not perform blocking I/O.
3. `flydpi_wfp_observer_stop()` unsubscribes before closing the engine.
4. Destruction happens only after the subscription is removed.
5. The event callback must not call `FwpmEngineClose0` or `FwpmNetEventUnsubscribe0` directly.

## What this does *not* do

- no packet payload modification;
- no TLS/SNI rewriting;
- no QUIC packet mutation;
- no global UDP blocking;
- no kernel patching;
- no LSP installation.

## Build

From a Visual Studio Developer PowerShell:

```powershell
cmake -S native/wfp-observer -B build/wfp-observer -A x64
cmake --build build/wfp-observer --config Release
```

The target links against `Fwpuclnt` and `Rpcrt4`, both supplied by the Windows SDK.

## Validation checklist

- Windows 10/11 x64.
- Base Filtering Engine (BFE) service running.
- Process has the WFP permissions required for opening the engine and subscribing to net events.
- Start observer -> generate ordinary browser traffic -> verify event counter increases.
- Stop observer -> verify no FlyDPI-owned handle remains open.
- Repeat start/stop 100 times to exercise cleanup/idempotence.
