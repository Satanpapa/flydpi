//! Bounds-checked IPv4/TCP/UDP metadata parser.
//!
//! This parser only reads packet bytes and produces normalized metadata. It never
//! mutates the input buffer and rejects malformed/truncated headers.

use crate::datapath::{FlowKey, PacketDirection, PacketMeta};
use crate::model::Protocol;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PacketParseError {
    Truncated,
    NotIpv4,
    InvalidIpv4Header,
    UnsupportedTransport,
    InvalidTransportHeader,
}

pub fn parse_ipv4_transport(
    bytes: &[u8],
    direction: PacketDirection,
) -> Result<PacketMeta, PacketParseError> {
    if bytes.len() < 20 {
        return Err(PacketParseError::Truncated);
    }
    let version = bytes[0] >> 4;
    if version != 4 {
        return Err(PacketParseError::NotIpv4);
    }
    let ihl = usize::from(bytes[0] & 0x0f) * 4;
    if ihl < 20 || bytes.len() < ihl {
        return Err(PacketParseError::InvalidIpv4Header);
    }

    let total_len = usize::from(u16::from_be_bytes([bytes[2], bytes[3]]));
    if total_len < ihl || total_len > bytes.len() {
        return Err(PacketParseError::Truncated);
    }

    let protocol = bytes[9];
    let mut remote_ip = [0u8; 16];
    remote_ip[..4].copy_from_slice(&bytes[16..20]);

    match protocol {
        6 => {
            if total_len < ihl + 20 {
                return Err(PacketParseError::InvalidTransportHeader);
            }
            let src_port = u16::from_be_bytes([bytes[ihl], bytes[ihl + 1]]);
            let dst_port = u16::from_be_bytes([bytes[ihl + 2], bytes[ihl + 3]]);
            let flags = bytes[ihl + 13];
            let data_offset = usize::from(bytes[ihl + 12] >> 4) * 4;
            if data_offset < 20 || ihl + data_offset > total_len {
                return Err(PacketParseError::InvalidTransportHeader);
            }
            Ok(PacketMeta {
                flow: FlowKey {
                    protocol: Protocol::Tcp,
                    remote_ip,
                    remote_port: dst_port,
                    local_port: src_port,
                },
                direction,
                payload_len: total_len - ihl - data_offset,
                tcp_flags: flags,
            })
        }
        17 => {
            if total_len < ihl + 8 {
                return Err(PacketParseError::InvalidTransportHeader);
            }
            let src_port = u16::from_be_bytes([bytes[ihl], bytes[ihl + 1]]);
            let dst_port = u16::from_be_bytes([bytes[ihl + 2], bytes[ihl + 3]]);
            let udp_len = usize::from(u16::from_be_bytes([bytes[ihl + 4], bytes[ihl + 5]]));
            if udp_len < 8 || ihl + udp_len > total_len {
                return Err(PacketParseError::InvalidTransportHeader);
            }
            Ok(PacketMeta {
                flow: FlowKey {
                    protocol: Protocol::Udp,
                    remote_ip,
                    remote_port: dst_port,
                    local_port: src_port,
                },
                direction,
                payload_len: udp_len - 8,
                tcp_flags: 0,
            })
        }
        _ => Err(PacketParseError::UnsupportedTransport),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_minimal_ipv4_tcp() {
        let mut p = vec![0u8; 40];
        p[0] = 0x45;
        p[2..4].copy_from_slice(&(40u16).to_be_bytes());
        p[9] = 6;
        p[16..20].copy_from_slice(&[1, 2, 3, 4]);
        p[20..22].copy_from_slice(&(50000u16).to_be_bytes());
        p[22..24].copy_from_slice(&(443u16).to_be_bytes());
        p[32] = 0x50;
        let meta = parse_ipv4_transport(&p, PacketDirection::Outbound).unwrap();
        assert_eq!(meta.flow.protocol, Protocol::Tcp);
        assert_eq!(meta.flow.remote_port, 443);
        assert_eq!(meta.flow.local_port, 50000);
        assert_eq!(meta.payload_len, 0);
    }

    #[test]
    fn rejects_truncated_header() {
        assert_eq!(
            parse_ipv4_transport(&[0x45, 0, 0], PacketDirection::Inbound),
            Err(PacketParseError::Truncated)
        );
    }
}
