# FlyDPI implementation roadmap

## Phase 1 — Foundation (current)

- [x] Repository and workspace
- [x] Rust C ABI lifecycle
- [x] Typed flow/probe models
- [x] Go classifier skeleton
- [x] ISP profile persistence
- [x] JSON-RPC contract
- [ ] Windows integration test harness

## Phase 2 — WFP observability

- Register a dedicated, signed development driver.
- Add owned filter/callout lifecycle management.
- Capture metadata required for diagnostics without modifying payloads.
- Record TCP reset, connect failure, and timeout events.
- Add deterministic cleanup and crash-recovery tests.

## Phase 3 — DNS diagnostics

- Resolve the same hostname through the system resolver and HTTPS DNS.
- Compare returned address sets with TTL-aware normalization.
- Classify disagreement as a DNS anomaly rather than automatically treating it as malicious poisoning.

## Phase 4 — Probe engine

- Parallelize independent probes.
- Add strict deadlines and cancellation.
- Store raw observations separately from derived classification.
- Add fixture-based tests for RST, timeout, DNS disagreement, and clean paths.

## Phase 5 — Policy adapters

Only after Phase 2-4 are stable, implement narrowly scoped, reversible transport policies for supported Windows networking layers. Every adapter must have a capability declaration, protocol guard, timeout, rollback path, and integration tests.

## Phase 6 — GUI

- Auto mode with confirmation.
- Manual mode with capability/risk display.
- Live diagnostic console.
- Profile management.

## Phase 7 — Packaging

- Reproducible builds.
- Driver signing strategy.
- Installer/uninstaller.
- Upgrade/rollback testing.
