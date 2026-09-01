//! WFP lifecycle abstraction.
//!
//! This module intentionally stops at ownership/state management. It does not
//! install traffic-transforming callouts. Packet mutation requires a validated
//! kernel driver and the correct WFP layer/injection path.

use std::collections::HashSet;
use std::sync::Mutex;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct FilterId(pub u64);

#[derive(Debug, Default)]
pub struct WfpState {
    filters: Mutex<HashSet<FilterId>>,
    initialized: Mutex<bool>,
}

impl WfpState {
    pub fn initialize(&self) -> Result<(), &'static str> {
        let mut initialized = self.initialized.lock().map_err(|_| "state poisoned")?;
        *initialized = true;
        Ok(())
    }

    pub fn register_owned_filter(&self, id: FilterId) -> Result<(), &'static str> {
        let initialized = self.initialized.lock().map_err(|_| "state poisoned")?;
        if !*initialized {
            return Err("WFP engine is not initialized");
        }
        drop(initialized);
        self.filters.lock().map_err(|_| "state poisoned")?.insert(id);
        Ok(())
    }

    pub fn reset(&self) -> Result<Vec<FilterId>, &'static str> {
        let mut filters = self.filters.lock().map_err(|_| "state poisoned")?;
        let removed = filters.drain().collect();
        *self.initialized.lock().map_err(|_| "state poisoned")? = false;
        Ok(removed)
    }

    pub fn owned_filter_count(&self) -> usize {
        self.filters.lock().map(|f| f.len()).unwrap_or(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lifecycle_is_idempotent() {
        let state = WfpState::default();
        state.initialize().unwrap();
        state.initialize().unwrap();
        state.register_owned_filter(FilterId(1)).unwrap();
        assert_eq!(state.owned_filter_count(), 1);
        let removed = state.reset().unwrap();
        assert_eq!(removed, vec![FilterId(1)]);
        assert_eq!(state.owned_filter_count(), 0);
    }
}
