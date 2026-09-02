package runtime

type Event struct {
	TimestampUnixMs uint64 `json:"timestamp_unix_ms"`
	Kind            uint32 `json:"kind"`
	Protocol        uint32 `json:"protocol"`
	RemotePort      uint16 `json:"remote_port"`
	ProcessID       uint32 `json:"process_id"`
	LatencyMs       uint64 `json:"latency_ms"`
	ErrorCode       int32  `json:"error_code"`
}

func convert(e runtimeEvent) Event {
	return Event{
		TimestampUnixMs: e.TimestampUnixMs,
		Kind:            e.Kind,
		Protocol:        e.Protocol,
		RemotePort:      e.RemotePort,
		ProcessID:       e.ProcessID,
		LatencyMs:       e.LatencyMs,
		ErrorCode:       e.ErrorCode,
	}
}
