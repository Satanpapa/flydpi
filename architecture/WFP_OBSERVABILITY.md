# WFP Observability Layer

## Role

This layer is the Windows-native ingress boundary for FlyDPI's low-level engine. It
uses the documented user-mode WFP management/event APIs to receive asynchronous
network-event notifications and converts them into a small, stable ABI record.

`FwpmNetEventSubscribe1` is supported on Windows 8+ and delivers `FWPM_NET_EVENT2`
records to the callback. Windows 10 1607+ also exposes `FwpmNetEventSubscribe2`;
FlyDPI currently keeps the version-1 callback ABI because Windows 10/11 are both
covered by the version-1 contract. The subscription requires the documented
WFP subscribe permission. See Microsoft Learn for the API contract.

## Pipeline

```text
WFP net-event callback
        |
        v
normalize FWPM_NET_EVENT2
        |
        v
stable FlyDpiEventSnapshot
        |
        v
bounded native queue (4096)
        |
        v
C ABI pop()
        |
        v
Rust datapath / classifier
```

## Snapshot contract

`FlyDpiEventSnapshot` contains only copied scalar/byte-array data. No Windows
pointers, `FWP_BYTE_BLOB` ownership, `SID*`, or WFP handles cross the ABI.

Address fields are copied only when the corresponding WFP flags state that the
fields are present. IPv4 and IPv6 use a fixed 16-byte representation. App ID is
copied into a maximum 64-byte prefix while retaining the original length.

Classify-drop events copy `msFwpResult`; other event types leave `result_code` at
zero rather than inventing a status.

## Queue semantics

The native observer owns a bounded FIFO queue with a capacity of 4096 snapshots.
When the queue is full, the oldest snapshot is discarded and a monotonic dropped
counter is incremented. The event callback never blocks on I/O and performs no
packet transformation.

Consumers use:

- `flydpi_wfp_observer_pop()` to remove the oldest event;
- `flydpi_wfp_observer_latest()` to inspect the newest queued event without removal;
- `flydpi_wfp_observer_event_count()` for total received events;
- `flydpi_wfp_observer_dropped_count()` for backpressure visibility.

## Lifetime rules

1. `FlyDpiWfpObserver` owns the WFP engine and subscription handles.
2. `flydpi_wfp_observer_stop()` unsubscribes before closing the engine.
3. The callback does not destroy or unsubscribe its own observer.
4. All data retained after the callback returns is an owned copy.

The subscription API is asynchronous, so cleanup ordering is intentionally kept
inside the native adapter rather than exposed to the Rust core.

## Security boundary

This layer is observation-only. It does not install packet-transforming callouts,
inject traffic, modify TCP/TLS/HTTP/QUIC data, or change firewall policy.

A future active datapath, if justified and separately reviewed, must use the
specific WFP layer/callout and injection mechanisms appropriate to that task rather
than extending this event observer into an implicit packet-rewrite path.

## Build

From a Visual Studio Developer PowerShell:

```powershell
cmake -S native/wfp-observer -B build/wfp-observer -A x64
cmake --build build/wfp-observer --config Release
```

The target links against `Fwpuclnt` and `Rpcrt4` from the Windows SDK.

## Validation checklist

- Windows 10/11 x64.
- Base Filtering Engine (BFE) running.
- Observer starts and receives ordinary browser traffic.
- Queue pop preserves FIFO ordering.
- Queue overflow increments the dropped counter instead of growing memory.
- Start/stop cycles release the subscription before engine shutdown.
- ABI records contain no live Windows pointers.
