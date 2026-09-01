# FlyDPI — System Architecture

## 1. Components

```text
                         +----------------------+
                         |      Qt6 / QML       |
                         |   Auto / Manual UI   |
                         +----------+-----------+
                                    |
                              JSON-RPC / IPC
                                    |
                         +----------v-----------+
                         |    Go Orchestrator   |
                         | probe/classify/state |
                         +----+------------+----+
                              |            |
                    C ABI    |            | HTTPS DNS
                              |            v
                    +---------v----+   +-------+-------+
                    | Rust Core    |   | DoH Resolver  |
                    | WFP adapter  |   | consistency   |
                    +------+-------+   +---------------+
                           |
                    Windows Filtering
                       Platform APIs
                           |
                    +------v-------+
                    | Windows TCP/ |
                    | UDP networking|
                    +--------------+
```

## 2. Layer responsibilities

### Rust core

Owns lifecycle and the stable C ABI:

- `init_wfp_filter()`
- `apply_tactic(tactic_id, handle)`
- `reset_filters()`

The Rust layer owns filter handles, callout state, tactic validation, telemetry, and cleanup. The first production implementation should keep packet mutation disabled until the corresponding WFP layer and injection path have been validated.

### Go orchestrator

Owns:

- startup probes;
- feature extraction;
- strategy selection;
- ISP profile persistence;
- JSON-RPC server;
- timeout/fallback state machine.

### GUI

The GUI is intentionally a thin client. It never manipulates WFP directly. Every state change goes through the Go JSON-RPC endpoint.

## 3. WFP design correction

ALE authorization layers are appropriate for connection authorization and metadata classification, but they are not a general-purpose payload-rewriting interface. A production implementation should use ALE layers for policy decisions and the appropriate stream/transport/network layers for any packet-level transformation.

The driver boundary should therefore expose a policy abstraction rather than assuming that `FWPM_LAYER_ALE_AUTH_CONNECT_V4` can directly rewrite TLS or QUIC bytes.

## 4. Tactic interface

Conceptual Rust interface:

```rust
pub trait BypassTactic {
    fn id(&self) -> TacticId;
    fn validate(&self, ctx: &FlowContext) -> Result<()>;
    fn apply(&self, ctx: &mut FlowContext) -> Result<TacticHandle>;
    fn rollback(&self, handle: TacticHandle) -> Result<()>;
}
```

Initial tactic IDs:

```text
1  FragmentationPolicy
2  TlsObfuscationPolicy
3  Http2Policy
4  DohPolicy
5  TcpTransportPolicy
99 LocalSocksFallback
```

These are policy identifiers, not permission to mutate arbitrary traffic. Each adapter must declare the exact WFP layer and supported protocol before activation.

## 5. Fallback state machine

```text
PROBE
  |
  v
CLASSIFY
  |
  v
TACTIC_1 --failure--> TACTIC_2 --failure--> TACTIC_3
  |                        |                        |
 success                  success                  success
  |                        |                        |
  +------------------------+------------------------+--> ACTIVE
                                                     |
                                                  failure
                                                     |
                                                     v
                                               TACTIC_4
                                                     |
                                                  failure
                                                     v
                                               TACTIC_5
                                                     |
                                                  failure
                                                     v
                                           MANUAL SOCKS FALLBACK
```

Per-attempt budget: 2 seconds by default. A timeout or transport reset ends the current attempt and advances the state machine. Every transition is logged with a reason code.

## 6. Safety requirements

- Driver/service cleanup must be idempotent.
- Filter handles must be tracked centrally.
- Reset must remove only FlyDPI-owned filters/callouts.
- No global UDP drop rule.
- No kernel patching.
- No persistence mechanism outside normal Windows service registration.
- All active policy changes require an audit event.
