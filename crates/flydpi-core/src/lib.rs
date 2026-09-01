mod model;

use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, Ordering};

pub use model::{DpiFeatures, FlowContext, ProbeResult, Protocol, TacticId};

static INITIALIZED: AtomicBool = AtomicBool::new(false);

/// Initializes the core lifecycle. This phase intentionally installs no
/// packet-rewriting policy.
#[no_mangle]
pub extern "C" fn init_wfp_filter() -> i32 {
    INITIALIZED.store(true, Ordering::SeqCst);
    0
}

/// Validates a policy identifier and records that the core is initialized.
/// Packet transformation is intentionally not enabled by this foundation.
#[no_mangle]
pub extern "C" fn apply_tactic(tactic_id: u32, handle: *mut c_void) -> i32 {
    if handle.is_null() {
        return -2;
    }
    if !INITIALIZED.load(Ordering::SeqCst) {
        return -3;
    }
    match tactic_id {
        1..=5 | 99 => 0,
        _ => -10,
    }
}

/// Idempotently clears FlyDPI-owned state.
#[no_mangle]
pub extern "C" fn reset_filters() -> i32 {
    INITIALIZED.store(false, Ordering::SeqCst);
    0
}
