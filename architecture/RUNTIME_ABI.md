# FlyDPI Runtime ABI

The Rust core exposes an opaque runtime facade intended for the Go orchestrator and future UI/service integrations.

```text
Go
 |
 | stable C ABI
 v
flydpi-core
 |
 +--> WfpObserverBridge
 +--> IngestWorker
 +--> Datapath
 +--> bounded EventRing
```

## Contract

`FlyDpiRuntime` is opaque. Foreign code must not depend on Rust layout.

`flydpi_runtime_start(observer_dll_path)` starts the observation worker and returns an opaque handle. `flydpi_runtime_poll()` returns one normalized event; `flydpi_runtime_drain()` returns up to a caller-provided bounded capacity.

Event codes are stable:

| kind | meaning |
|---:|---|
| 1 | packet observed |
| 2 | connect attempt |
| 3 | connect success |
| 4 | connect failure |
| 5 | reset observed |
| 6 | receive timeout |
| 7 | DNS address mismatch |

Protocol codes follow the IP protocol number for TCP/UDP (`6`/`17`); `0` means other/unknown.

## Ownership

The caller owns the opaque runtime handle returned by `flydpi_runtime_start` and must release it exactly once with `flydpi_runtime_stop`.

Buffers passed to `poll`/`drain` are caller-owned and remain valid for the duration of the call only.

The Rust runtime owns the WFP observer bridge, its worker thread, the flow table, and its bounded event ring.

## Safety boundary

The runtime is observation-only. It does not expose packet mutation, injection, spoofing, filtering policy execution, or raw kernel pointers through this ABI.

## Integration requirement

The native observer DLL and Rust runtime DLL must use matching `FlyDpiEventSnapshot` layouts. ABI changes require updating both headers and Rust `#[repr(C)]` structures together.
