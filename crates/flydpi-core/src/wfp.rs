//! WFP lifecycle abstraction.
//!
//! This module intentionally stops at ownership/state management. It does not
//! install traffic-transforming callouts. Packet mutation requires a validated
//! kernel driver and the correct WFP layer/injection path.

use std::collections::BTreeSet;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct FilterId(pub u64);

#[derive(Debug, Default)]
pub struct WfpState {
    initialized: bool,
    filters: BTreeSet<FilterId>,
    next_id: u64,
}

impl WfpState {
    pub fn initialize(&mut self) -> Result<(), &'static str> {
        if self.initialized { return Ok(()); }
        self.initialized = true;
        self.next_id = 1;
        Ok(())
    }

    pub fn initialized(&self) -> bool { self.initialized }

    pub fn register_owned_filter(&mut self) -> Result<FilterId, &'static str> {
        if !self.initialized { return Err("WFP_NOT_INITIALIZED"); }
        let id = FilterId(self.next_id);
        self.next_id = self.next_id.checked_add(1).ok_or("FILTER_ID_EXHAUSTED")?;
        self.filters.insert(id);
        Ok(id)
    }

    pub fn remove_owned_filter(&mut self, id: FilterId) -> bool { self.filters.remove(&id) }
    pub fn owned_filter_count(&self) -> usize { self.filters.len() }

    pub fn reset(&mut self) -> Result<(), &'static str> {
        self.filters.clear();
        self.initialized = false;
        self.next_id = 0;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lifecycle_is_idempotent() {
        let mut state = WfpState::default();
        state.initialize().unwrap();
        state.initialize().unwrap();
        let id = state.register_owned_filter().unwrap();
        assert_eq!(state.owned_filter_count(), 1);
        assert!(state.remove_owned_filter(id));
        state.reset().unwrap();
        assert!(!state.initialized());
    }

    #[test]
    fn cannot_register_before_init() {
        let mut state = WfpState::default();
        assert_eq!(state.register_owned_filter(), Err("WFP_NOT_INITIALIZED"));
    }
}
