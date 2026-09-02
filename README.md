# FlyDPI

Windows 10/11 local network diagnostics and WFP research framework.

> **Current release status:** diagnostic MVP plus a low-level observation/datapath foundation and passive transport analysis. The application can inspect DNS/TCP/TLS behaviour and WFP telemetry, present a structured diagnosis, persist local profiles/history, track normalized flows, and pass observed WFP events through a bounded Rust ingest pipeline. Active packet transformation, censorship-evasion tactics, and kernel callout packet rewriting are not enabled in this build.

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
        |
        +----> EventRing / diagnostics
        |
        +----> passive TLS / QUIC analysis
```

The Rust core provides:

- stable flow identity and packet metadata;
- bounds-checked IPv4/TCP/UDP parsing;
- bounded idle-flow tracking;
- bounded WFP event ingest with overflow accounting;
- passive TLS ClientHello/SNI inspection;
- passive QUIC long-header/Initial identification.

Transport analysis is read-only. It does not alter packet bytes, synthesize packets, manipulate TCP state, rewrite TLS/QUIC fields, or install network policies.

## Notes

The low-level engine remains observation-only. The Rust core is not yet embedded into the packaged Go backend as a production packet-processing service.

All active changes to network policy must remain explicit, auditable, reversible, and scoped to FlyDPI-owned state.

## License

TBD. See repository history before redistribution.
