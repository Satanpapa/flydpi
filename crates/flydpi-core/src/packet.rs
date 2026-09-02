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
    if bytes[0] >> 4 != 4 {
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
    let mut src_ip = [0u8; 16];
    let mut dst_ip = [0u8; 16];
    src_ip[..4].copy_from_slice(&bytes[12..16]);
    dst_ip[..4].copy_from_slice(&bytes[16..20]);
    let remote_ip = match direction {
        PacketDirection::Outbound => dst_ip,
        PacketDirection::Inbound => src_ip,
    };

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
                    remote_port: match direction {
                        PacketDirection::Outbound => dst_port,
                        PacketDirection::Inbound => src_port,
                    },
                    local_port: match direction {
                        PacketDirection::Outbound => src_port,
                        PacketDirection::Inbound => dst_port,
                    },
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
                    remote_port: match direction {
                        PacketDirection::Outbound => dst_port,
                        PacketDirection::Inbound => src_port,
                    },
                    local_port: match direction {
                        PacketDirection::Outbound => src_port,
                        PacketDirection::Inbound => dst_port,
                    },
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

    fn tcp_packet(src: [u8; 4], dst: [u8; 4], src_port: u16, dst_port: u16) -> Vec<u8> {
        let mut p = vec![0u8; 40];
        p[0] = 0x45;
        p[2..4].copy_from_slice(&(40u16).to_be_bytes());
        p[9] = 6;
        p[12..16].copy_from_slice(&src);
        p[16..20].copy_from_slice(&dst);
        p[20..22].copy_from_slice(&src_port.to_be_bytes());
        p[22..24].copy_from_slice(&dst_port.to_be_bytes());
        p[32] = 0x50;
        p
    }

    #[test]
    fn parses_outbound_ipv4_tcp() {
        let p = tcp_packet([10, 0, 0, 2], [1, 2, 3, 4], 50000, 443);
        let meta = parse_ipv4_transport(&p, PacketDirection::Outbound).unwrap();
        assert_eq!(meta.flow.remote_ip[..4], [1, 2, 3, 4]);
        assert_eq!(meta.flow.remote_port, 443);
        assert_eq!(meta.flow.local_port, 50000);
    }

    #[test]
    fn parses_inbound_ipv4_tcp() {
        let p = tcp_packet([1, 2, 3, 4], [10, 0, 0, 2], 443, 50000);
        let meta = parse_ipv4_transport(&p, PacketDirection::Inbound).unwrap();
        assert_eq!(meta.flow.remote_ip[..4], [1, 2, 3, 4]);
        assert_eq!(meta.flow.remote_port, 443);
        assert_eq!(meta.flow.local_port, 50000);
    }

    #[test]
    fn rejects_truncated_header() {
        assert_eq!(
            parse_ipv4_transport(&[0x45, 0, 0], PacketDirection::Inbound),
            Err(PacketParseError::Truncated)
        );
    }
}
