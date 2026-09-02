//! Bounded diagnostic event ring.
//!
//! Kernel/user-mode producers must never be able to grow process memory without
//! limit. Once capacity is reached, the oldest event is discarded and the drop
//! counter remains observable.

use std::collections::VecDeque;

use crate::telemetry::{EventKind, NetworkEvent};

#[derive(Debug)]
pub struct EventRing {
    capacity: usize,
    events: VecDeque<NetworkEvent>,
    dropped: u64,
}

impl EventRing {
    pub fn new(capacity: usize) -> Self {
        assert!(capacity > 0, "event ring capacity must be positive");
        Self {
            capacity,
            events: VecDeque::with_capacity(capacity),
            dropped: 0,
        }
    }

    pub fn push(&mut self, event: NetworkEvent) {
        if self.events.len() == self.capacity {
            self.events.pop_front();
            self.dropped = self.dropped.saturating_add(1);
        }
        self.events.push_back(event);
    }

    pub fn len(&self) -> usize { self.events.len() }
    pub fn dropped(&self) -> u64 { self.dropped }
    pub fn is_empty(&self) -> bool { self.events.is_empty() }

    pub fn drain(&mut self, max: usize) -> Vec<NetworkEvent> {
        let take = max.min(self.events.len());
        self.events.drain(..take).collect()
    }

    pub fn clear(&mut self) {
        self.events.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn event(n: u64) -> NetworkEvent {
        NetworkEvent {
            timestamp_unix_ms: n,
            kind: EventKind::ConnectAttempt,
            protocol: "tcp".into(),
            remote_addr: "127.0.0.1".into(),
            remote_port: 443,
            process_id: Some(1),
            latency_ms: None,
            error_code: None,
        }
    }

    #[test]
    fn drops_oldest_when_full() {
        let mut ring = EventRing::new(2);
        ring.push(event(1));
        ring.push(event(2));
        ring.push(event(3));
        assert_eq!(ring.len(), 2);
        assert_eq!(ring.dropped(), 1);
        assert_eq!(ring.drain(8)[0].timestamp_unix_ms, 2);
    }
}
