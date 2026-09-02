# FlyDPI

Windows 10/11 local network diagnostics and WFP research framework.

> **Current release status:** diagnostic MVP plus an event-driven low-level datapath foundation. The application can inspect DNS/TCP/TLS behaviour and WFP telemetry, present a structured diagnosis, persist local profiles/history, and track normalized network events in the native/Rust pipeline. Active packet transformation, censorship-evasion tactics, and kernel callout packet rewriting are not enabled in this build.

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
  FlyDPI.exe              # single user-facing launcher
  bin\flydpi.exe          # local Go diagnostic backend
  ui\flydpi-ui.exe       # Qt6 GUI
  ...                     # Qt runtime/QML dependencies
```

Launch with:

```powershell
.\dist\FlyDPI\FlyDPI.exe
```

The launcher starts the local backend, starts the GUI, and terminates the backend when the GUI exits.

## Project layout

```text
crates/flydpi-core/       Rust core + flow datapath/WFP lifecycle/telemetry
native/wfp-observer/      Native WFP event-ingest adapter
orchestrator/             Go diagnostic backend / JSON-RPC
launcher/                 Single-executable Windows launcher
ui/                       Qt6/QML GUI
config/                   Example ISP profile
architecture/              System, datapath, and protocol documentation
scripts/                  Windows build/package helpers
```

## Low-level datapath phase

The low-level engine now has three explicit layers:

1. **Packet normalization** — bounds-checked IPv4/TCP/UDP parsing into stable `PacketMeta` records.
2. **Flow datapath** — stable flow identity, direction, counters, lifetime and bounded expiry.
3. **Native WFP ingest** — asynchronous WFP net-event subscription, stable ABI snapshots, bounded FIFO queue and overflow telemetry.

The native observer copies only owned scalar/byte-array data from `FWPM_NET_EVENT2`; no Windows kernel/user pointers cross into the Rust core. The queue is intentionally bounded and drops the oldest record on overflow while exposing a drop counter.

See:

- `architecture/DATAPATH_ENGINE.md`
- `architecture/WFP_OBSERVABILITY.md`

## Notes

The Rust core is still not embedded into the Go backend as a production packet-processing path. The release script validates the Rust workspace and packages the currently functional Go + Qt diagnostic application.

All active changes to network policy must remain explicit, auditable, reversible, and scoped to FlyDPI-owned state.

## License

TBD. See repository history before redistribution.
