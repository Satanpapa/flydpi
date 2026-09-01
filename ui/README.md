# FlyDPI UI

The UI is intentionally split into a QML presentation layer and a small Qt/C++ integration layer.

## Runtime contract

- GUI connects only to `127.0.0.1:27654`.
- Transport is newline-delimited JSON-RPC over TCP.
- The GUI never opens WFP handles and never applies low-level network policy directly.
- `probe.run` returns diagnostics; future policy operations must require an explicit confirmation flow.

## UX states

`READY -> PROBING -> RESULT` and `READY -> ERROR`.

The dashboard should always distinguish **diagnosis** from **policy activation**. A successful probe does not implicitly activate any traffic transformation.
