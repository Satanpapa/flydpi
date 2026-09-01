use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum Protocol {
    Tcp,
    Udp,
    Unknown,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum TacticId {
    FragmentationPolicy = 1,
    TlsObfuscationPolicy = 2,
    Http2Policy = 3,
    DohPolicy = 4,
    TcpTransportPolicy = 5,
    LocalSocksFallback = 99,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct DpiFeatures {
    pub rst_detected: bool,
    pub poisoning_detected: bool,
    pub timeout_detected: bool,
    pub frag_works: bool,
    pub sni_spoof_works: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FlowContext {
    pub protocol: Protocol,
    pub remote_port: u16,
    pub hostname: Option<String>,
    pub started_unix_ms: u64,
}
