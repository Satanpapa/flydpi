# FlyDPI

Windows 10/11 local network diagnostics and WFP research framework.

> **Current release status:** diagnostic MVP plus a low-level observation/datapath foundation and passive transport/flow analysis. The application can inspect DNS/TCP/TLS behaviour and WFP telemetry, present a structured diagnosis, persist local profiles/history, track normalized flows, pass observed WFP events through a bounded Rust ingest pipeline, and expose an opaque runtime to the Go orchestrator. Active packet transformation, censorship-evasion tactics, and kernel callout packet rewriting are not enabled in this build.

## Quick build on Windows

Prerequisites:

- Windows 10/11 x64
- Visual Studio 2022 Build Tools with Desktop C++ and Windows SDK
- CMake 3.24+
- Rust stable + `x86_64-pc-windows-msvc`
- Go 1.24+
- Qt 6.5+ with `windeployqt` available in `PATH`

From the repository root, run PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\build-release.ps1
```

The portable distribution is created under:

```text
dist\FlyDPI\
  FlyDPI.exe
  bin\flydpi.exe
  bin\flydpi-core.dll
  bin\flydpi_wfp_observer.dll
  ui\flydpi-ui.exe
  ...
```

## Low-level engine

The current low-level pipeline is:

```text
Windows WFP net-events
        |
        v
native observer
        |
   bounded queue
        |
        v
Rust WFP bridge
        |
   ingest worker
        +----> Datapath / flow table
        |          |
        |          +--> FlowSessionAnalyzer
        |
        +----> EventRing / diagnostics
        |
        +----> passive TLS / QUIC analysis
        |
        +----> opaque Rust runtime
        |
        v
Go orchestrator
        |
        v
Qt live telemetry UI
```

The Rust core provides:

- stable flow identity and packet metadata;
- bounds-checked IPv4/TCP/UDP parsing;
- bounded idle-flow tracking;
- bounded WFP event ingest with overflow accounting;
- passive TLS ClientHello/SNI inspection;
- passive QUIC long-header/Initial identification;
- stateful TCP lifecycle signals including SYN, SYN-ACK, ACK, FIN and RST;
- explainable flow diagnoses for reset, incomplete handshake and idle timeout suspicion;
- a stable opaque runtime API consumed by the Windows Go backend.

The native WFP observer owns the Windows handles and exports a fixed-width snapshot ABI. The Rust bridge loads that observer dynamically and keeps Windows-specific types outside the core datapath. The Go backend loads the Rust runtime dynamically when the packaged DLLs are present and exposes bounded telemetry through `telemetry.poll`. The Qt client polls that endpoint and renders live WFP activity.

## Documentation

- `architecture/DATAPATH_ENGINE.md` — datapath design and invariants
- `architecture/WFP_OBSERVABILITY.md` — Windows WFP observation boundary
- `architecture/WFP_INGEST.md` — native-to-Rust ingest lifecycle
- `architecture/FLOW_ANALYSIS.md` — flow/session correlation
- `architecture/RUNTIME_ABI.md` — foreign-runtime ABI contract

## Validation

The repository contains Rust unit tests for packet parsing, flow tracking, transport parsing and runtime normalization. Full Windows integration requires a local Windows environment with BFE/WFP available. Run the release build locally with the script above and verify that `status.get` reports `runtime.enabled=true` when the WFP observer can start.

## Notes

The low-level engine remains observation-only. No packet payload is injected, forged, split, dropped, or rewritten. All active changes to network policy must remain explicit, auditable, reversible, and scoped to FlyDPI-owned state.

## License

TBD. See repository history before redistribution.
