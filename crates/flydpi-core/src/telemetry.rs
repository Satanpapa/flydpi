//! Transport-neutral telemetry model for the classifier.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum EventKind {
    ConnectAttempt,
    ConnectSuccess,
    ConnectFailure,
    ResetObserved,
    ReceiveTimeout,
    DnsAddressMismatch,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkEvent {
    pub timestamp_unix_ms: u64,
    pub kind: EventKind,
    pub protocol: String,
    pub remote_addr: String,
    pub remote_port: u16,
    pub process_id: Option<u32>,
    pub latency_ms: Option<u64>,
    pub error_code: Option<i32>,
}

#[derive(Debug, Default)]
pub struct EventBuffer {
    events: Vec<NetworkEvent>,
}

impl EventBuffer {
    pub fn push(&mut self, event: NetworkEvent) { self.events.push(event); }
    pub fn len(&self) -> usize { self.events.len() }
    pub fn drain(&mut self) -> Vec<NetworkEvent> { std::mem::take(&mut self.events) }
}
