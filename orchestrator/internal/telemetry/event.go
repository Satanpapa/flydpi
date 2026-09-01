package telemetry

import "time"

type Protocol uint8

const (
	ProtocolUnknown Protocol = iota
	ProtocolTCP
	ProtocolUDP
)

type Event struct {
	Timestamp time.Time `json:"timestamp"`
	IPVersion uint32    `json:"ip_version"`
	Protocol  Protocol  `json:"protocol"`
	Direction uint8     `json:"direction"`
	LocalPort uint16    `json:"local_port"`
	RemotePort uint16   `json:"remote_port"`
	ProcessID uint32    `json:"process_id"`
	EventCode uint32    `json:"event_code"`
	Status    uint32    `json:"status"`
}

func (e Event) IsTCPResetLike() bool {
	// Keep the first classifier conservative: a WFP result/event code alone
	// is not proof of forged RST injection. It is a signal for correlation.
	return e.Protocol == ProtocolTCP && e.Status != 0
}
