# WFP ingest pipeline

The low-level engine now has an explicit observation pipeline:

```text
Windows WFP net-event callback
        |
        v
bounded native queue (4096)
        |
        | stable C ABI snapshot
        v
runtime-loaded Rust bridge
        |
        v
background ingest worker
        |
        +--> flow datapath
        |
        +--> bounded EventRing
```

## Ownership

The native observer owns the WFP engine/session and subscription handles. The Rust
bridge owns the loaded observer module and observer lifetime. The ingest worker owns
the bridge after startup and releases it only after the stop flag is observed.

## Backpressure

The native queue is bounded. On overflow it evicts the oldest snapshot and increments
an observable drop counter. The Rust event ring has its own bounded capacity and drop
counter.

## ABI boundary

Only fixed-width scalar fields and fixed-size byte arrays cross the C ABI. No WFP
pointers, `FWPM_*` structures, `SID*`, `FWP_BYTE_BLOB*`, or kernel-owned buffers are
exposed to Rust.

## Direction

`FWPM_NET_EVENT_HEADER2` reports local/remote endpoints, but a net-event record is not
a generic packet capture record. The bridge therefore marks direction as `Unknown`
rather than guessing. A later packet-layer adapter may provide explicit direction.

## Error handling

Invalid IP versions, unsupported transports, and incomplete endpoint metadata are
rejected before entering the flow table. Worker startup failures are returned to the
caller instead of being hidden inside the background thread.

## Non-goals

This pipeline remains observation-only. It does not inject, forge, split, drop, or
rewrite traffic and does not execute censorship-evasion tactics.
