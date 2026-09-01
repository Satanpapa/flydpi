# Telemetry bridge

The Go side consumes normalized event records rather than Windows SDK structs. The event stream is diagnostic-only in this phase.

## Correlation rules

An individual WFP event is not sufficient to label traffic as censorship or forged TCP reset. The classifier must correlate:

1. connection target;
2. monotonic timestamps;
3. TCP lifecycle outcome;
4. DNS answer set;
5. probe result.

A `timeout` is defined at the probe layer, not inferred solely from a WFP event.

A `RST_detected` feature should be set only when the TCP probe observes an abnormal reset correlated with the target connection. WFP telemetry is supporting evidence.
