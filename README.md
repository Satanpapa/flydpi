# FlyDPI

Windows 10/11 local network diagnostics and traffic-policy research framework.

> **Status:** architecture/scaffold phase. The repository intentionally does not ship packet-evasion or censorship-bypass logic yet. Low-level packet handling must be implemented and validated against Windows networking semantics, stability requirements, and applicable law before enabling any active transformation.

## Goals

- Rust core for Windows networking integration and policy application.
- Go orchestrator for probing, classification, profiles, and JSON-RPC control.
- Qt6/QML GUI (planned) for Auto/Manual operation.
- Built-in DNS consistency checks using HTTPS-based DNS resolution.
- Deterministic fallback state machine with observable diagnostics.
- No external VPN/proxy dependency in the core architecture.

## Repository layout

```text
crates/
  flydpi-core/       Rust core and C ABI boundary
  flydpi-protocol/   Shared protocol/data definitions
orchestrator/
  cmd/flydpi/        Go entrypoint
  internal/          classifier, profiles, rpc
config/
  example-profile.json
proto/
  json-rpc.md
architecture/
  SYSTEM.md
  SECURITY.md
scripts/
  windows/           development/install helpers
ui/
  qml/               GUI scaffold
```

## Important implementation notes

Several items in the original design require correction before implementation:

1. `MSG_PARTIAL` is not a general Windows API for splitting an arbitrary TCP/TLS application record. TCP segmentation must be handled at an appropriate packet/filter layer or by controlling application writes.
2. WFP ALE authorization layers are primarily classification/authorization layers; arbitrary payload rewriting belongs at packet/stream layers with the correct WFP data structures and injection APIs.
3. QUIC Initial packets have protocol invariants. Changing Connection ID or packet-number fields is not a generic ALE operation and can invalidate cryptographic/protocol state. The initial implementation therefore treats QUIC transformation as an explicit research adapter rather than silently mutating packets.
4. A Windows service/driver boundary must be fail-closed with respect to system stability: uninstall/reset must restore filters and handles cleanly.

See `architecture/SYSTEM.md` for the corrected architecture.

## Development

Prerequisites:

- Windows 10/11 x64
- Rust stable + `x86_64-pc-windows-msvc`
- Go 1.24+
- Visual Studio Build Tools / Windows SDK
- Qt 6 for the GUI phase

Build the Rust workspace:

```powershell
cargo build --workspace
```

Build the Go orchestrator:

```powershell
go build ./orchestrator/cmd/flydpi
```

## License

TBD. Do not redistribute production binaries until the project license and driver-signing policy are finalized.
