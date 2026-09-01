//! Windows-native WFP user-mode session adapter.
//!
//! This adapter opens a dynamic WFP engine session and provides ownership
//! metadata for FlyDPI-managed objects. It intentionally does not register
//! a kernel callout or modify packet payloads.

#[cfg(windows)]
use std::ptr::null_mut;

#[cfg(windows)]
use windows::Win32::NetworkManagement::WindowsFilteringPlatform::{
    FwpmEngineClose0, FwpmEngineOpen0, FWPM_SESSION_FLAG_DYNAMIC, FWPM_SESSION0,
};

#[cfg(windows)]
use windows::Win32::Foundation::HANDLE;

#[cfg(windows)]
pub struct NativeWfpEngine {
    handle: HANDLE,
}

#[cfg(windows)]
unsafe impl Send for NativeWfpEngine {}

#[cfg(windows)]
unsafe impl Sync for NativeWfpEngine {}

#[cfg(windows)]
impl NativeWfpEngine {
    pub fn open_dynamic() -> windows::core::Result<Self> {
        let mut raw = HANDLE::default();
        let mut session = FWPM_SESSION0::default();
        session.flags = FWPM_SESSION_FLAG_DYNAMIC;

        unsafe {
            FwpmEngineOpen0(
                None,
                1,
                None,
                &session,
                &mut raw,
            )?;
        }

        Ok(Self { handle: raw })
    }

    pub fn is_open(&self) -> bool {
        !self.handle.is_invalid()
    }

    pub fn raw(&self) -> HANDLE {
        self.handle
    }
}

#[cfg(windows)]
impl Drop for NativeWfpEngine {
    fn drop(&mut self) {
        if !self.handle.is_invalid() {
            unsafe {
                let mut handle = self.handle;
                let _ = FwpmEngineClose0(&mut handle);
                self.handle = HANDLE::default();
            }
        }
    }
}

#[cfg(not(windows))]
pub struct NativeWfpEngine;

#[cfg(not(windows))]
impl NativeWfpEngine {
    pub fn open_dynamic() -> Result<Self, &'static str> {
        Err("WINDOWS_ONLY")
    }

    pub fn is_open(&self) -> bool {
        false
    }
}

#[allow(dead_code)]
fn _null_marker() {
    #[cfg(windows)]
    let _ = null_mut::<u8>();
}
