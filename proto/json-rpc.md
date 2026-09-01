# FlyDPI JSON-RPC IPC

Transport: localhost-only TCP socket or Windows named pipe adapter. The initial portable contract uses JSON-RPC 2.0 messages.

## Methods

### `status.get`

Returns current service state, active tactic, last probe result, and error code.

### `probe.run`

Runs the configured diagnostic probe set.

### `profile.list`

Lists available ISP profiles.

### `profile.activate`

Activates a named profile after validation.

### `tactic.preview`

Returns the expected scope, protocol support, timeout, and rollback plan without changing WFP state.

### `tactic.apply`

Requests activation of a validated tactic. Auto mode requires an explicit confirmation token from the GUI.

### `tactic.reset`

Removes FlyDPI-owned active policy state.

## Error model

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32010,
    "message": "TACTIC_UNSUPPORTED",
    "data": {
      "protocol": "quic",
      "reason": "transport adapter not available"
    }
  }
}
```

The GUI must treat unknown error codes as non-success and never silently retry an active packet policy.
