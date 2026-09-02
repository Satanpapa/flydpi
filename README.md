# FlyDPI

Windows 10/11 local network diagnostics and WFP research framework.

> **Current release status:** diagnostic MVP plus a low-level observation/datapath foundation and passive transport/flow analysis. The application can inspect DNS/TCP/TLS behaviour and WFP telemetry, present a structured diagnosis, persist local profiles/history, track normalized flows, pass observed WFP events through a bounded Rust ingest pipeline, and expose an opaque C ABI runtime for future orchestrator integration. Active packet transformation, censorship-evasion tactics, and kernel callout packet rewriting are not enabled in this build.

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
        +----> opaque C ABI runtime
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
- a stable opaque runtime API for future Go integration.

The native WFP observer owns the Windows handles and exports a fixed-width snapshot ABI. The Rust bridge loads that observer dynamically and keeps Windows-specific types outside the core datapath. The runtime API in `native/flydpi_runtime.h` exposes only caller-owned buffers and opaque handles.

## Documentation

- `architecture/DATAPATH_ENGINE.md` — datapath design and invariants
- `architecture/WFP_OBSERVABILITY.md` — Windows WFP observation boundary
- `architecture/WFP_INGEST.md` — native-to-Rust ingest lifecycle
- `architecture/FLOW_ANALYSIS.md` — flow/session correlation
- `architecture/RUNTIME_ABI.md` — foreign-runtime ABI contract

## Notes

The low-level engine remains observation-only. The packaged Go backend does not yet enable the Rust runtime automatically, and the release script still packages the currently functional diagnostic application rather than a kernel traffic-transforming product.

All active changes to network policy must remain explicit, auditable, reversible, and scoped to FlyDPI-owned state.

## License

TBD. See repository history before redistribution.
