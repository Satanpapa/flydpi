//! Windows-native WFP user-mode session adapter.
//!
//! Microsoft documents `FwpmEngineOpen0` as the user-mode entry point for
//! opening a filter-engine session; a dynamic session automatically removes
//! objects created in that session when it ends. This module uses that
//! lifecycle but does not register kernel callouts or rewrite packets.

#[cfg(windows)]
use windows::Win32::Foundation::HANDLE;

#[cfg(windows)]
use windows::Win32::NetworkManagement::WindowsFilteringPlatform::{
    FwpmEngineClose0, FwpmEngineOpen0, FWPM_SESSION_FLAG_DYNAMIC, FWPM_SESSION0,
};

#[cfg(windows)]
use windows::Win32::System::Rpc::RPC_C_AUTHN_DEFAULT;

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

        let rc = unsafe {
            FwpmEngineOpen0(
                None,
                RPC_C_AUTHN_DEFAULT as u32,
                None,
                Some(&session as *const FWPM_SESSION0),
                &mut raw,
            )
        };

        if rc != 0 {
            return Err(windows::core::Error::new(
                windows::core::HRESULT::from_win32(rc),
                format!("FwpmEngineOpen0 failed with Win32 error {rc}"),
            ));
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
                let _ = FwpmEngineClose0(self.handle);
            }
            self.handle = HANDLE::default();
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

#[cfg(all(test, windows))]
mod tests {
    use super::NativeWfpEngine;

    #[test]
    fn opens_and_closes_dynamic_session() {
        let engine = NativeWfpEngine::open_dynamic().expect("WFP/BFE unavailable");
        assert!(engine.is_open());
    }
}
