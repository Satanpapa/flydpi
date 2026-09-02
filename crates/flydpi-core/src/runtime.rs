//! C ABI runtime facade for the low-level observation engine.
//!
//! The facade exposes opaque ownership to foreign runtimes (for example Go)
//! without exposing Rust layouts or Windows FFI types. It remains observation-only.

use std::ffi::c_char;
use std::ffi::CStr;
use std::ptr;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use crate::datapath::Datapath;
use crate::ingest::IngestWorker;
use crate::ring::EventRing;
use crate::telemetry::{EventKind, NetworkEvent};

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct FlyDpiRuntimeEvent {
    pub timestamp_unix_ms: u64,
    pub kind: u32,
    pub protocol: u32,
    pub remote_port: u16,
    pub process_id: u32,
    pub latency_ms: u64,
    pub error_code: i32,
    pub reserved: u32,
}

#[repr(C)]
pub struct FlyDpiRuntime {
    datapath: Arc<Mutex<Datapath>>,
    events: Arc<Mutex<EventRing>>,
    worker: Option<IngestWorker>,
}

fn event_kind_code(kind: EventKind) -> u32 {
    match kind {
        EventKind::PacketObserved => 1,
        EventKind::ConnectAttempt => 2,
        EventKind::ConnectSuccess => 3,
        EventKind::ConnectFailure => 4,
        EventKind::ResetObserved => 5,
        EventKind::ReceiveTimeout => 6,
        EventKind::DnsAddressMismatch => 7,
    }
}

fn protocol_code(protocol: &str) -> u32 {
    match protocol {
        "tcp" => 6,
        "udp" => 17,
        _ => 0,
    }
}

impl From<NetworkEvent> for FlyDpiRuntimeEvent {
    fn from(event: NetworkEvent) -> Self {
        Self {
            timestamp_unix_ms: event.timestamp_unix_ms,
            kind: event_kind_code(event.kind),
            protocol: protocol_code(&event.protocol),
            remote_port: event.remote_port,
            process_id: event.process_id.unwrap_or(0),
            latency_ms: event.latency_ms.unwrap_or(0),
            error_code: event.error_code.unwrap_or(0),
            reserved: 0,
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn flydpi_runtime_start(dll_path: *const c_char) -> *mut FlyDpiRuntime {
    if dll_path.is_null() { return ptr::null_mut(); }
    let path = match CStr::from_ptr(dll_path).to_str() {
        Ok(value) if !value.is_empty() => value.to_owned(),
        _ => return ptr::null_mut(),
    };

    let datapath = Arc::new(Mutex::new(Datapath::new()));
    let events = Arc::new(Mutex::new(EventRing::new(4096)));
    let worker = match IngestWorker::start(path, Arc::clone(&datapath), Arc::clone(&events)) {
        Ok(value) => value,
        Err(_) => return ptr::null_mut(),
    };

    Box::into_raw(Box::new(FlyDpiRuntime { datapath, events, worker: Some(worker) }))
}

#[no_mangle]
pub unsafe extern "C" fn flydpi_runtime_poll(
    runtime: *mut FlyDpiRuntime,
    out_event: *mut FlyDpiRuntimeEvent,
) -> u32 {
    if runtime.is_null() || out_event.is_null() { return 87; }
    let runtime = &mut *runtime;
    let event = match runtime.events.lock() {
        Ok(mut ring) => ring.drain(1).into_iter().next(),
        Err(_) => None,
    };
    match event {
        Some(event) => {
            *out_event = event.into();
            1
        }
        None => 0,
    }
}

#[no_mangle]
pub unsafe extern "C" fn flydpi_runtime_stop(runtime: *mut FlyDpiRuntime) {
    if runtime.is_null() { return; }
    let mut runtime = Box::from_raw(runtime);
    if let Some(worker) = runtime.worker.take() { let _ = worker.stop(); }
}

#[no_mangle]
pub unsafe extern "C" fn flydpi_runtime_drain(
    runtime: *mut FlyDpiRuntime,
    out_events: *mut FlyDpiRuntimeEvent,
    capacity: usize,
) -> usize {
    if runtime.is_null() || out_events.is_null() || capacity == 0 { return 0; }
    let runtime = &mut *runtime;
    let events = match runtime.events.lock() {
        Ok(mut ring) => ring.drain(capacity),
        Err(_) => return 0,
    };
    for (index, event) in events.iter().cloned().enumerate() {
        *out_events.add(index) = event.into();
    }
    events.len()
}

#[no_mangle]
pub unsafe extern "C" fn flydpi_runtime_sleep_hint(milliseconds: u64) {
    std::thread::sleep(Duration::from_millis(milliseconds.min(1000)));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn event_codes_are_stable() {
        let event = NetworkEvent {
            timestamp_unix_ms: 1,
            kind: EventKind::ResetObserved,
            protocol: "tcp".into(),
            remote_addr: "1.2.3.4".into(),
            remote_port: 443,
            process_id: Some(42),
            latency_ms: Some(7),
            error_code: Some(5),
        };
        let abi: FlyDpiRuntimeEvent = event.into();
        assert_eq!(abi.kind, 5);
        assert_eq!(abi.protocol, 6);
        assert_eq!(abi.process_id, 42);
    }
}
