//! Low-level, transformation-free network datapath.

use std::collections::HashMap;
use std::time::{Duration, Instant};

use crate::model::{FlowContext, Protocol};
use crate::telemetry::{EventKind, NetworkEvent};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct FlowKey {
    pub protocol: Protocol,
    pub remote_ip: [u8; 16],
    pub remote_port: u16,
    pub local_port: u16,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PacketDirection {
    Outbound,
    Inbound,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PacketMeta {
    pub flow: FlowKey,
    pub direction: PacketDirection,
    pub payload_len: usize,
    pub tcp_flags: u8,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DatapathAction {
    Pass,
    Observe,
}

#[derive(Debug, Clone)]
pub struct FlowState {
    pub context: FlowContext,
    pub created_at: Instant,
    pub last_seen: Instant,
    pub packets: u64,
    pub bytes: u64,
}

#[derive(Debug, Default)]
pub struct Datapath {
    flows: HashMap<FlowKey, FlowState>,
}

impl Datapath {
    pub fn new() -> Self { Self::default() }

    pub fn on_packet(&mut self, meta: PacketMeta, now: Instant) -> DatapathAction {
        let entry = self.flows.entry(meta.flow).or_insert_with(|| FlowState {
            context: FlowContext {
                protocol: meta.flow.protocol,
                remote_addr: format_remote(meta.flow.remote_ip),
                remote_port: meta.flow.remote_port,
                hostname: None,
                started_unix_ms: 0,
            },
            created_at: now,
            last_seen: now,
            packets: 0,
            bytes: 0,
        });
        entry.last_seen = now;
        entry.packets = entry.packets.saturating_add(1);
        entry.bytes = entry.bytes.saturating_add(meta.payload_len as u64);
        DatapathAction::Observe
    }

    pub fn flow(&self, key: &FlowKey) -> Option<&FlowState> { self.flows.get(key) }
    pub fn flow_count(&self) -> usize { self.flows.len() }

    pub fn expire_idle(&mut self, now: Instant, idle: Duration) -> usize {
        let before = self.flows.len();
        self.flows.retain(|_, flow| now.duration_since(flow.last_seen) <= idle);
        before - self.flows.len()
    }

    pub fn clear(&mut self) { self.flows.clear(); }

    pub fn event_for(meta: PacketMeta, pid: u32, timestamp_unix_ms: u64) -> NetworkEvent {
        NetworkEvent {
            timestamp_unix_ms,
            kind: EventKind::PacketObserved,
            protocol: match meta.flow.protocol {
                Protocol::Tcp => "tcp".into(),
                Protocol::Udp => "udp".into(),
                Protocol::Unknown => "unknown".into(),
            },
            remote_addr: format_remote(meta.flow.remote_ip),
            remote_port: meta.flow.remote_port,
            process_id: Some(pid),
            latency_ms: None,
            error_code: None,
        }
    }
}

fn format_remote(addr: [u8; 16]) -> String {
    if addr[4..].iter().all(|b| *b == 0) {
        format!("{}.{}.{}.{}", addr[0], addr[1], addr[2], addr[3])
    } else {
        std::net::Ipv6Addr::from(addr).to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn key() -> FlowKey {
        FlowKey { protocol: Protocol::Tcp, remote_ip: [1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0], remote_port: 443, local_port: 51000 }
    }

    #[test]
    fn tracks_flow_without_transforming_payload() {
        let now = Instant::now();
        let mut dp = Datapath::new();
        let meta = PacketMeta { flow: key(), direction: PacketDirection::Unknown, payload_len: 120, tcp_flags: 0x18 };
        assert_eq!(dp.on_packet(meta, now), DatapathAction::Observe);
        assert_eq!(dp.on_packet(meta, now + Duration::from_millis(1)), DatapathAction::Observe);
        let flow = dp.flow(&key()).unwrap();
        assert_eq!(flow.packets, 2);
        assert_eq!(flow.bytes, 240);
    }

    #[test]
    fn expires_idle_flows() {
        let now = Instant::now();
        let mut dp = Datapath::new();
        let meta = PacketMeta { flow: key(), direction: PacketDirection::Unknown, payload_len: 1, tcp_flags: 0 };
        dp.on_packet(meta, now);
        assert_eq!(dp.expire_idle(now + Duration::from_secs(6), Duration::from_secs(5)), 1);
        assert_eq!(dp.flow_count(), 0);
    }
}
