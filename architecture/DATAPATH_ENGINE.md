# FlyDPI low-level datapath engine

## Goal

The core engine must provide a deterministic, low-allocation flow datapath that can
consume normalized packet metadata from Windows networking hooks and feed the
existing diagnostics/event ring. This phase is **observation-first**: packets are
never rewritten, forged, split, or dropped by the Rust core.

## Pipeline

```text
Windows network observation
        |
        v
+--------------------------+
| metadata normalization   |
| 5-tuple / direction      |
| protocol / ports / size  |
+------------+-------------+
             |
             v
+--------------------------+
| flow table               |
| creation / counters      |
| last-seen / idle expiry  |
+------------+-------------+
             |
       +-----+------+
       |            |
       v            v
   event ring    classifier
       |            |
       +-----+------+
             v
         diagnostics
```

## Flow identity

`FlowKey` is intentionally independent from payload contents. The current key is
protocol + remote address + remote port + local port. A future Windows adapter
may add process identity and local address, but that extension must preserve a
stable key representation for correlation.

## Windows boundary

The next implementation stage should add a Windows adapter with three explicit
responsibilities:

1. Acquire metadata from the appropriate supported WFP observation layer.
2. Convert it into `PacketMeta` without exposing raw kernel pointers to the core.
3. Push bounded `NetworkEvent` records into the user-mode event ring.

The adapter must own all FFI lifetime rules and must never call payload mutation
from the observation path.

## Threading

The datapath object is deliberately single-owner. A Windows adapter should feed it
through a bounded queue or sharded flow table rather than placing a global mutex on
every packet. Flow expiry should run periodically on a maintenance thread.

## Backpressure

The event ring is bounded. When it is full, the oldest diagnostic event may be
dropped and the drop counter must remain observable. The packet datapath itself
must not allocate unbounded memory in response to event volume.

## Error model

Malformed metadata is rejected at the Windows adapter boundary. Core methods should
remain infallible where possible and use saturating counters for packet/byte totals.
Unexpected kernel errors are surfaced as diagnostic events rather than being hidden.

## Explicit non-goals in this phase

- TLS ClientHello/SNI rewriting
- HTTP header modification
- TCP sequence manipulation
- QUIC packet/header mutation
- packet injection or spoofing
- censorship-evasion policy execution

Those are separate, security-sensitive components and require dedicated design,
tests, and Windows-specific validation before being connected to this datapath.
