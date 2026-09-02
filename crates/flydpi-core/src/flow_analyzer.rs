//! Stateful transport/session analysis over normalized flow observations.
//!
//! Observation-only: correlates TCP lifecycle and passive TLS/QUIC metadata.

use std::collections::HashMap;
use std::time::{Duration, Instant};

use crate::datapath::{FlowKey, PacketMeta};
use crate::model::Protocol;
use crate::transport::{analyze_payload, TlsClientHelloInfo, TransportInfo};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TcpLifecycle { New, SynSent, Established, FinSeen, Reset }

#[derive(Debug, Clone, Default)]
pub struct FlowSignals {
    pub syn_seen: bool,
    pub syn_ack_seen: bool,
    pub ack_seen: bool,
    pub fin_seen: bool,
    pub rst_seen: bool,
    pub packets: u64,
    pub bytes: u64,
    pub first_seen: Option<Instant>,
    pub last_seen: Option<Instant>,
    pub connect_latency: Option<Duration>,
    pub tls_client_hello_seen: bool,
    pub tls_sni: Option<String>,
    pub quic_long_header_seen: bool,
    pub quic_version: Option<u32>,
    pub quic_packet_type: Option<u8>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FlowDiagnosis { HealthyTransport, TcpReset, TcpHandshakeIncomplete, IdleTimeoutSuspected, TlsClientHelloObserved, QuicLongHeaderObserved, Unknown }

#[derive(Debug, Clone)]
pub struct FlowSnapshot { pub key: FlowKey, pub lifecycle: TcpLifecycle, pub signals: FlowSignals, pub diagnosis: FlowDiagnosis }

#[derive(Debug, Default)]
pub struct FlowSessionAnalyzer { flows: HashMap<FlowKey, FlowSignals> }

impl FlowSessionAnalyzer {
    pub fn new() -> Self { Self::default() }

    pub fn observe_packet(&mut self, packet: &PacketMeta, payload: &[u8], now: Instant) {
        let signals = self.flows.entry(packet.flow).or_default();
        signals.packets = signals.packets.saturating_add(1);
        signals.bytes = signals.bytes.saturating_add(packet.payload_len as u64);
        signals.first_seen.get_or_insert(now);
        signals.last_seen = Some(now);

        if packet.flow.protocol == Protocol::Tcp {
            let flags = packet.tcp_flags;
            let syn = flags & 0x02 != 0;
            let ack = flags & 0x10 != 0;
            if syn && !ack { signals.syn_seen = true; }
            if syn && ack { signals.syn_ack_seen = true; }
            if ack { signals.ack_seen = true; }
            if flags & 0x01 != 0 { signals.fin_seen = true; }
            if flags & 0x04 != 0 { signals.rst_seen = true; }
            if signals.connect_latency.is_none() && signals.syn_seen && signals.syn_ack_seen {
                if let Some(first) = signals.first_seen { signals.connect_latency = now.checked_duration_since(first); }
            }
        }

        match analyze_payload(packet.flow.protocol, payload) {
            Ok(TransportInfo::TlsClientHello(TlsClientHelloInfo { sni, .. })) => {
                signals.tls_client_hello_seen = true;
                if sni.is_some() { signals.tls_sni = sni; }
            }
            Ok(TransportInfo::QuicLongHeader(info)) => {
                signals.quic_long_header_seen = true;
                signals.quic_version = Some(info.version);
                signals.quic_packet_type = Some(info.packet_type);
            }
            Ok(TransportInfo::Unknown) | Err(_) => {}
        }
    }

    pub fn snapshot(&self, key: &FlowKey, now: Instant, timeout: Duration) -> Option<FlowSnapshot> {
        let signals = self.flows.get(key)?.clone();
        let lifecycle = lifecycle(&signals);
        let diagnosis = diagnosis(&signals, lifecycle, now, timeout);
        Some(FlowSnapshot { key: *key, lifecycle, signals, diagnosis })
    }

    pub fn expire(&mut self, now: Instant, idle: Duration) -> usize {
        let before = self.flows.len();
        self.flows.retain(|_, flow| flow.last_seen.map(|t| now.duration_since(t) <= idle).unwrap_or(false));
        before - self.flows.len()
    }

    pub fn flow_count(&self) -> usize { self.flows.len() }
}

fn lifecycle(s: &FlowSignals) -> TcpLifecycle {
    if s.rst_seen { return TcpLifecycle::Reset; }
    if s.fin_seen { return TcpLifecycle::FinSeen; }
    if s.syn_seen && s.syn_ack_seen && s.ack_seen { return TcpLifecycle::Established; }
    if s.syn_seen { return TcpLifecycle::SynSent; }
    TcpLifecycle::New
}

fn diagnosis(s: &FlowSignals, state: TcpLifecycle, now: Instant, timeout: Duration) -> FlowDiagnosis {
    if s.rst_seen { return FlowDiagnosis::TcpReset; }
    if state == TcpLifecycle::SynSent {
        if let Some(last) = s.last_seen { if now.duration_since(last) >= timeout { return FlowDiagnosis::IdleTimeoutSuspected; } }
        return FlowDiagnosis::TcpHandshakeIncomplete;
    }
    if s.tls_client_hello_seen { return FlowDiagnosis::TlsClientHelloObserved; }
    if s.quic_long_header_seen { return FlowDiagnosis::QuicLongHeaderObserved; }
    if state == TcpLifecycle::Established { return FlowDiagnosis::HealthyTransport; }
    FlowDiagnosis::Unknown
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::datapath::PacketDirection;

    fn key() -> FlowKey { FlowKey { protocol: Protocol::Tcp, remote_ip: [1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0], remote_port: 443, local_port: 50000 } }

    #[test]
    fn detects_reset() {
        let now = Instant::now();
        let mut analyzer = FlowSessionAnalyzer::new();
        let packet = PacketMeta { flow: key(), direction: PacketDirection::Inbound, payload_len: 0, tcp_flags: 0x14 };
        analyzer.observe_packet(&packet, &[], now);
        let snapshot = analyzer.snapshot(&key(), now, Duration::from_secs(5)).unwrap();
        assert_eq!(snapshot.lifecycle, TcpLifecycle::Reset);
        assert_eq!(snapshot.diagnosis, FlowDiagnosis::TcpReset);
    }
}
