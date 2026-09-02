//! Runtime-loaded bridge from the native WFP observer into the Rust datapath.

use std::ffi::{c_void, CString};
use crate::datapath::{Datapath, FlowKey, PacketDirection, PacketMeta};
use crate::model::Protocol;
use crate::telemetry::{EventKind, NetworkEvent};

#[cfg(windows)]
use windows::Win32::Foundation::{FreeLibrary, HINSTANCE};
#[cfg(windows)]
use windows::Win32::System::LibraryLoader::{GetProcAddress, LoadLibraryA};

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct WfpEventSnapshot {
    pub timestamp_100ns: u64,
    pub flags: u32,
    pub ip_version: u32,
    pub protocol: u8,
    pub local_port: u16,
    pub remote_port: u16,
    pub local_addr: [u8; 16],
    pub remote_addr: [u8; 16],
    pub event_type: u32,
    pub result_code: u32,
    pub has_local_addr: u8,
    pub has_remote_addr: u8,
    pub has_app_id: u8,
    pub reserved0: u8,
    pub app_id_length: u32,
    pub app_id_prefix: [u8; 64],
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BridgeError {
    UnsupportedPlatform,
    InvalidPath,
    LoadFailed,
    MissingSymbol,
    StartFailed(u32),
    WorkerStartFailed,
}

#[cfg(windows)]
type ObserverHandle = *mut c_void;
#[cfg(windows)]
type StartFn = unsafe extern "system" fn(*mut ObserverHandle) -> u32;
#[cfg(windows)]
type StopFn = unsafe extern "system" fn(ObserverHandle);
#[cfg(windows)]
type PopFn = unsafe extern "system" fn(ObserverHandle, *mut WfpEventSnapshot) -> u32;
#[cfg(windows)]
type DroppedFn = unsafe extern "system" fn(ObserverHandle) -> u64;

#[cfg(windows)]
pub struct WfpObserverBridge {
    module: HINSTANCE,
    observer: ObserverHandle,
    stop: StopFn,
    pop: PopFn,
    dropped: DroppedFn,
}

#[cfg(windows)]
unsafe impl Send for WfpObserverBridge {}

#[cfg(windows)]
impl WfpObserverBridge {
    pub fn open(path: &str) -> Result<Self, BridgeError> {
        let path = CString::new(path).map_err(|_| BridgeError::InvalidPath)?;
        let module = unsafe { LoadLibraryA(windows::core::PCSTR(path.as_ptr() as *const u8)) }
            .map_err(|_| BridgeError::LoadFailed)?;

        let symbol = |name: &str| -> Result<*const c_void, BridgeError> {
            let name = CString::new(name).map_err(|_| BridgeError::MissingSymbol)?;
            let ptr = unsafe { GetProcAddress(module, windows::core::PCSTR(name.as_ptr() as *const u8)) };
            ptr.map(|p| p as *const c_void).ok_or(BridgeError::MissingSymbol)
        };

        let start: StartFn = unsafe { std::mem::transmute(symbol("flydpi_wfp_observer_start")?) };
        let stop: StopFn = unsafe { std::mem::transmute(symbol("flydpi_wfp_observer_stop")?) };
        let pop: PopFn = unsafe { std::mem::transmute(symbol("flydpi_wfp_observer_pop")?) };
        let dropped: DroppedFn = unsafe { std::mem::transmute(symbol("flydpi_wfp_observer_dropped_count")?) };

        let mut observer = std::ptr::null_mut();
        let rc = unsafe { start(&mut observer) };
        if rc != 0 {
            unsafe { FreeLibrary(module) };
            return Err(BridgeError::StartFailed(rc));
        }
        Ok(Self { module, observer, stop, pop, dropped })
    }

    pub fn pop(&self) -> Option<WfpEventSnapshot> {
        let mut snapshot = WfpEventSnapshot::default();
        let rc = unsafe { (self.pop)(self.observer, &mut snapshot) };
        if rc == 0 { Some(snapshot) } else { None }
    }

    pub fn dropped_count(&self) -> u64 { unsafe { (self.dropped)(self.observer) } }
}

#[cfg(windows)]
impl Drop for WfpObserverBridge {
    fn drop(&mut self) {
        unsafe {
            (self.stop)(self.observer);
            FreeLibrary(self.module);
        }
    }
}

#[cfg(not(windows))]
pub struct WfpObserverBridge;

#[cfg(not(windows))]
impl WfpObserverBridge {
    pub fn open(_path: &str) -> Result<Self, BridgeError> { Err(BridgeError::UnsupportedPlatform) }
    pub fn pop(&self) -> Option<WfpEventSnapshot> { None }
    pub fn dropped_count(&self) -> u64 { 0 }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SnapshotClass { Transport, Other, Invalid }

pub fn classify_snapshot(snapshot: &WfpEventSnapshot) -> SnapshotClass {
    if snapshot.ip_version != 4 && snapshot.ip_version != 6 { return SnapshotClass::Invalid; }
    if snapshot.protocol == 6 || snapshot.protocol == 17 { SnapshotClass::Transport } else { SnapshotClass::Other }
}

pub fn snapshot_to_event(snapshot: &WfpEventSnapshot) -> Option<NetworkEvent> {
    if classify_snapshot(snapshot) == SnapshotClass::Invalid { return None; }
    Some(NetworkEvent {
        timestamp_unix_ms: filetime_to_unix_ms(snapshot.timestamp_100ns),
        kind: EventKind::PacketObserved,
        protocol: match snapshot.protocol { 6 => "tcp", 17 => "udp", _ => "other" }.to_owned(),
        remote_addr: format_ip(snapshot.remote_addr),
        remote_port: snapshot.remote_port,
        process_id: None,
        latency_ms: None,
        error_code: (snapshot.result_code != 0).then_some(snapshot.result_code as i32),
    })
}

pub fn snapshot_to_meta(snapshot: &WfpEventSnapshot) -> Option<PacketMeta> {
    let protocol = match snapshot.protocol { 6 => Protocol::Tcp, 17 => Protocol::Udp, _ => return None };
    if snapshot.ip_version != 4 && snapshot.ip_version != 6 { return None; }
    if snapshot.remote_port == 0 && snapshot.local_port == 0 { return None; }
    Some(PacketMeta {
        flow: FlowKey { protocol, remote_ip: snapshot.remote_addr, remote_port: snapshot.remote_port, local_port: snapshot.local_port },
        direction: PacketDirection::Unknown,
        payload_len: 0,
        tcp_flags: 0,
    })
}

pub fn feed_snapshot(datapath: &mut Datapath, snapshot: &WfpEventSnapshot) -> Option<NetworkEvent> {
    let meta = snapshot_to_meta(snapshot)?;
    datapath.on_packet(meta, std::time::Instant::now());
    snapshot_to_event(snapshot)
}

fn filetime_to_unix_ms(value: u64) -> u64 {
    const WINDOWS_TO_UNIX_100NS: u64 = 116_444_736_000_000_000;
    value.saturating_sub(WINDOWS_TO_UNIX_100NS) / 10_000
}

fn format_ip(addr: [u8; 16]) -> String {
    if addr[4..].iter().all(|b| *b == 0) { format!("{}.{}.{}.{}", addr[0], addr[1], addr[2], addr[3]) }
    else { std::net::Ipv6Addr::from(addr).to_string() }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn normalizes_tcp_snapshot() {
        let snapshot = WfpEventSnapshot { ip_version: 4, protocol: 6, remote_port: 443, local_port: 50000, remote_addr: [1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0], ..Default::default() };
        let meta = snapshot_to_meta(&snapshot).unwrap();
        assert_eq!(meta.flow.protocol, Protocol::Tcp);
        assert_eq!(meta.flow.remote_port, 443);
        assert_eq!(meta.direction, PacketDirection::Unknown);
    }
    #[test]
    fn converts_filetime_to_unix_epoch() { assert_eq!(filetime_to_unix_ms(116_444_736_000_000_000), 0); }
    #[test]
    fn rejects_unknown_ip_version() {
        let snapshot = WfpEventSnapshot { ip_version: 3, protocol: 6, remote_port: 1, ..Default::default() };
        assert!(snapshot_to_event(&snapshot).is_none());
    }
}
