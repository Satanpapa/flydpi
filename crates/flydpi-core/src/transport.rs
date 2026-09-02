//! Passive transport analysis for observed payloads.
//!
//! The analyzer is deliberately read-only: it never modifies, reorders, or
//! synthesizes network bytes. It extracts bounded metadata useful for diagnosis.

use crate::model::Protocol;

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct TlsClientHelloInfo {
    pub legacy_version: u16,
    pub sni: Option<String>,
    pub handshake_len: usize,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct QuicHeaderInfo {
    pub version: u32,
    pub packet_type: u8,
    pub destination_cid_len: u8,
    pub source_cid_len: u8,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TransportInfo {
    TlsClientHello(TlsClientHelloInfo),
    QuicLongHeader(QuicHeaderInfo),
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransportParseError {
    Truncated,
    Malformed,
    Unsupported,
}

pub fn analyze_payload(protocol: Protocol, payload: &[u8]) -> Result<TransportInfo, TransportParseError> {
    match protocol {
        Protocol::Tcp => analyze_tls_client_hello(payload),
        Protocol::Udp => analyze_quic_header(payload),
        Protocol::Unknown => Err(TransportParseError::Unsupported),
    }
}

pub fn analyze_tls_client_hello(payload: &[u8]) -> Result<TransportInfo, TransportParseError> {
    if payload.len() < 5 {
        return Err(TransportParseError::Truncated);
    }
    if payload[0] != 0x16 {
        return Ok(TransportInfo::Unknown);
    }
    let record_version = u16::from_be_bytes([payload[1], payload[2]]);
    let record_len = usize::from(u16::from_be_bytes([payload[3], payload[4]]));
    if record_len > payload.len().saturating_sub(5) {
        return Err(TransportParseError::Truncated);
    }
    let hs = &payload[5..5 + record_len];
    if hs.len() < 4 || hs[0] != 0x01 {
        return Ok(TransportInfo::Unknown);
    }
    let handshake_len = ((hs[1] as usize) << 16) | ((hs[2] as usize) << 8) | hs[3] as usize;
    if handshake_len > hs.len().saturating_sub(4) {
        return Err(TransportParseError::Truncated);
    }
    let body = &hs[4..4 + handshake_len];
    if body.len() < 34 {
        return Err(TransportParseError::Malformed);
    }

    let legacy_version = u16::from_be_bytes([body[0], body[1]]);
    let session_len = usize::from(body[34]);
    let mut pos = 35usize;
    if pos + session_len > body.len() {
        return Err(TransportParseError::Malformed);
    }
    pos += session_len;
    if pos + 2 > body.len() {
        return Err(TransportParseError::Malformed);
    }
    let cipher_len = usize::from(u16::from_be_bytes([body[pos], body[pos + 1]]));
    pos += 2;
    if pos + cipher_len > body.len() {
        return Err(TransportParseError::Malformed);
    }
    pos += cipher_len;
    if pos >= body.len() {
        return Ok(TransportInfo::TlsClientHello(TlsClientHelloInfo { legacy_version, sni: None, handshake_len }));
    }
    let compression_len = usize::from(body[pos]);
    pos += 1;
    if pos + compression_len > body.len() {
        return Err(TransportParseError::Malformed);
    }
    pos += compression_len;
    if pos + 2 > body.len() {
        return Err(TransportParseError::Malformed);
    }
    let extensions_len = usize::from(u16::from_be_bytes([body[pos], body[pos + 1]]));
    pos += 2;
    if pos + extensions_len > body.len() {
        return Err(TransportParseError::Malformed);
    }
    let extensions_end = pos + extensions_len;
    let mut sni = None;
    while pos + 4 <= extensions_end {
        let ext_type = u16::from_be_bytes([body[pos], body[pos + 1]]);
        let ext_len = usize::from(u16::from_be_bytes([body[pos + 2], body[pos + 3]]));
        pos += 4;
        if pos + ext_len > extensions_end {
            return Err(TransportParseError::Malformed);
        }
        if ext_type == 0x0000 && ext_len >= 5 {
            let ext = &body[pos..pos + ext_len];
            let list_len = usize::from(u16::from_be_bytes([ext[0], ext[1]]));
            if list_len + 2 > ext.len() {
                return Err(TransportParseError::Malformed);
            }
            let mut np = 2usize;
            while np + 3 <= 2 + list_len {
                let name_type = ext[np];
                let name_len = usize::from(u16::from_be_bytes([ext[np + 1], ext[np + 2]]));
                np += 3;
                if np + name_len > 2 + list_len || np + name_len > ext.len() {
                    return Err(TransportParseError::Malformed);
                }
                if name_type == 0 && name_len > 0 {
                    if let Ok(name) = std::str::from_utf8(&ext[np..np + name_len]) {
                        sni = Some(name.to_owned());
                    }
                    break;
                }
                np += name_len;
            }
        }
        pos += ext_len;
    }

    let _ = record_version;
    Ok(TransportInfo::TlsClientHello(TlsClientHelloInfo { legacy_version, sni, handshake_len }))
}

pub fn analyze_quic_header(payload: &[u8]) -> Result<TransportInfo, TransportParseError> {
    if payload.is_empty() {
        return Err(TransportParseError::Truncated);
    }
    let first = payload[0];
    if first & 0x80 == 0 {
        return Ok(TransportInfo::Unknown);
    }
    if payload.len() < 6 {
        return Err(TransportParseError::Truncated);
    }
    let packet_type = (first >> 4) & 0x03;
    let version = u32::from_be_bytes([payload[1], payload[2], payload[3], payload[4]]);
    let dcid_len = payload[5] as usize;
    let mut pos = 6usize;
    if dcid_len > 20 || pos + dcid_len + 1 > payload.len() {
        return Err(TransportParseError::Malformed);
    }
    pos += dcid_len;
    let scid_len = payload[pos] as usize;
    if scid_len > 20 || pos + 1 + scid_len > payload.len() {
        return Err(TransportParseError::Malformed);
    }
    Ok(TransportInfo::QuicLongHeader(QuicHeaderInfo {
        version,
        packet_type,
        destination_cid_len: dcid_len as u8,
        source_cid_len: scid_len as u8,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identifies_quic_initial_shape() {
        let payload = [0xC0, 0, 0, 0, 1, 4, 1, 2, 3, 4, 2, 5, 6];
        match analyze_quic_header(&payload).unwrap() {
            TransportInfo::QuicLongHeader(info) => {
                assert_eq!(info.version, 1);
                assert_eq!(info.packet_type, 0);
                assert_eq!(info.destination_cid_len, 4);
                assert_eq!(info.source_cid_len, 2);
            }
            _ => panic!("expected QUIC long header"),
        }
    }

    #[test]
    fn rejects_short_tls_record() {
        assert_eq!(analyze_tls_client_hello(&[0x16, 0x03]), Err(TransportParseError::Truncated));
    }
}
