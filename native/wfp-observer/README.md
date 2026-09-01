# WFP observer

This native component is a diagnostics-only adapter around Windows Filtering Platform network-event subscription.

It owns a dynamic WFP engine session and a network-event subscription. It does not install packet transformation callouts, alter payloads, or drop all UDP traffic.

## Build contract

- C++17
- Windows SDK
- Link against `fwpuclnt.lib`
- Runtime requires the Windows Filtering Platform user-mode API.

The C ABI is intentionally small:

```text
flydpi_wfp_observer_start()
flydpi_wfp_observer_stop()
flydpi_wfp_observer_event_count()
```

The current bridge exposes a counter only. Detailed `FWPM_NET_EVENT` normalization remains in the next step so native SDK structures do not leak into the Go ABI.
