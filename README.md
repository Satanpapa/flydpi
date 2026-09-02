# FlyDPI

Windows 10/11 local network diagnostics and WFP research framework.

> **Current release status:** diagnostic MVP plus a low-level observation datapath. The application can inspect DNS/TCP/TLS behaviour and WFP telemetry, present a structured diagnosis, persist local profiles/history, and route normalized WFP event snapshots through the Rust flow engine. Active packet transformation, censorship-evasion tactics, and kernel callout packet rewriting are not enabled in this build.

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

The Rust core now contains the first observation datapath layers:

- `datapath.rs` — stable flow identity, normalized packet metadata, counters and idle expiry;
- `packet.rs` — bounds-checked IPv4/TCP/UDP metadata parsing;
- `wfp_bridge.rs` — stable ABI snapshot normalization and optional runtime loading of the native WFP observer;
- `ingest.rs` — background pump from the native WFP queue into the Rust datapath and bounded event ring;
- `ring.rs` — bounded event buffering with observable drops.

The native observer uses `FwpmEngineOpen0` and `FwpmNetEventSubscribe1`, owns its WFP handles, and exports only a fixed-width snapshot ABI. The Rust side deliberately treats net-event direction as unknown instead of guessing from endpoint fields.

See `architecture/DATAPATH_ENGINE.md` and `architecture/WFP_INGEST.md` for the dataflow and lifecycle rules.

## Notes

The low-level engine remains observation-only. It does not inject, forge, split, drop, or rewrite network traffic. The Rust core is not yet embedded into the packaged Go backend as a production packet-processing service.

All active changes to network policy must remain explicit, auditable, reversible, and scoped to FlyDPI-owned state.

## License

TBD. See repository history before redistribution.
