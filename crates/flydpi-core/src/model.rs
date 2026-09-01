use serde::{Deserialize, Serialize};

#[repr(u32)]
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum TacticId {
    FragmentationPolicy = 1,
    TlsObfuscationPolicy = 2,
    Http2Policy = 3,
    DohPolicy = 4,
    TcpTransportPolicy = 5,
    LocalSocksFallback = 99,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct FlowContext {
    pub protocol: Protocol,
    pub remote_addr: String,
    pub remote_port: u16,
    pub hostname: Option<String>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, Default)]
pub enum Protocol {
    #[default]
    Tcp,
    Udp,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct DpiFeatures {
    pub rst_detected: bool,
    pub poisoning_detected: bool,
    pub timeout_detected: bool,
    pub frag_works: bool,
    pub sni_spoof_works: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProbeResult {
    pub hostname: String,
    pub tcp_ok: bool,
    pub tls_ok: bool,
    pub doh_addresses: Vec<String>,
    pub features: DpiFeatures,
    pub latency_ms: Option<u64>,
}
