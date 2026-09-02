mod datapath;
mod flow_analyzer;
mod ingest;
mod model;
mod native_wfp;
mod packet;
mod ring;
mod runtime;
mod telemetry;
mod transport;
mod wfp;
mod wfp_bridge;

use std::ffi::c_void;
use std::sync::{Mutex, OnceLock};

pub use datapath::{Datapath, DatapathAction, FlowKey, FlowState, PacketDirection, PacketMeta};
pub use flow_analyzer::{FlowDiagnosis, FlowSessionAnalyzer, FlowSignals, FlowSnapshot, TcpLifecycle};
pub use ingest::{IngestStats, IngestWorker};
pub use model::{DpiFeatures, FlowContext, ProbeResult, Protocol, TacticId};
pub use native_wfp::NativeWfpEngine;
pub use packet::{parse_ipv4_transport, PacketParseError};
pub use ring::EventRing;
pub use runtime::{FlyDpiRuntime, FlyDpiRuntimeEvent};
pub use telemetry::{EventBuffer, EventKind, NetworkEvent};
pub use transport::{analyze_payload, analyze_quic_header, analyze_tls_client_hello, QuicHeaderInfo, TlsClientHelloInfo, TransportInfo, TransportParseError};
pub use wfp::{FilterId, WfpState};
pub use wfp_bridge::{classify_snapshot, feed_snapshot, snapshot_to_event, snapshot_to_meta, BridgeError, SnapshotClass, WfpEventSnapshot, WfpObserverBridge};

static STATE: OnceLock<Mutex<WfpState>> = OnceLock::new();

fn state() -> &'static Mutex<WfpState> {
    STATE.get_or_init(|| Mutex::new(WfpState::default()))
}

/// Initializes the core lifecycle. On Windows this also opens a dynamic WFP
/// management session; no packet-rewriting filters are installed.
#[no_mangle]
pub extern "C" fn init_wfp_filter() -> i32 {
    #[cfg(windows)]
    { if NativeWfpEngine::open_dynamic().is_err() { return -20; } }
    match state().lock() {
        Ok(mut guard) => guard.initialize().map(|_| 0).unwrap_or(-1),
        Err(_) => -4,
    }
}

/// Validates a policy identifier. Packet transformation is not enabled by
/// this foundation build.
#[no_mangle]
pub extern "C" fn apply_tactic(tactic_id: u32, handle: *mut c_void) -> i32 {
    if handle.is_null() { return -2; }
    if !matches!(tactic_id, 1..=5 | 99) { return -10; }
    if state().lock().is_err() { return -4; }
    0
}

/// Idempotently clears FlyDPI-owned state.
#[no_mangle]
pub extern "C" fn reset_filters() -> i32 {
    match state().lock() {
        Ok(mut guard) => guard.reset().map(|_| 0).unwrap_or(-1),
        Err(_) => -4,
    }
}
