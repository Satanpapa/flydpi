# DiagnosticReport contract

`DiagnosticReport` is the single source of truth for the GUI result screen.

## Severity

- `ok`: no clear anomaly.
- `warning`: one or more transport checks failed; cause is not proven.
- `critical`: an independent consistency check detected a strong anomaly such as DNS answer divergence.

## Stage model

Each stage reports `id`, `title`, `status`, `progress`, `duration_ns`, optional `summary`, and optional `details`.

Current stages:

1. `dns` — system resolver vs independent public DoH comparison.
2. `tcp` — TCP connect results.
3. `tls` — TLS handshake results.
4. `wfp` — WFP telemetry availability/correlation status.

The report is diagnostic-only. A failed stage is evidence for investigation, not proof of a specific censorship mechanism.

## UI rule

The main result screen exposes one primary action derived from `recommended_action`. No automatic network transformation is executed as a side effect of displaying a report.
