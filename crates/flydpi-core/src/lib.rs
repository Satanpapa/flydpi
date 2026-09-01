use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, Ordering};

static INITIALIZED: AtomicBool = AtomicBool::new(false);

/// Initialize the FlyDPI policy engine.
///
/// This scaffold deliberately does not install packet-transforming filters.
/// The production driver boundary will be added only after layer/injection
/// semantics are validated.
#[no_mangle]
pub extern "C" fn init_wfp_filter() -> i32 {
    INITIALIZED.store(true, Ordering::SeqCst);
    0
}

/// Apply a validated tactic to an opaque engine handle.
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

/// Remove all FlyDPI-owned state.
#[no_mangle]
pub extern "C" fn reset_filters() -> i32 {
    INITIALIZED.store(false, Ordering::SeqCst);
    0
}
