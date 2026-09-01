package telemetry

import (
	"encoding/binary"
	"fmt"
	"time"
)

// DecodeSnapshot converts the fixed-width native C ABI snapshot into a Go
// event. No Windows SDK structs cross the language boundary.
func DecodeSnapshot(buf []byte) (Event, error) {
	const size = 8 + 4 + 4 + 1 + 2 + 2 + 4 + 4
	if len(buf) < size {
		return Event{}, fmt.Errorf("snapshot too small: %d < %d", len(buf), size)
	}

	e := Event{}
	n := 0
	filetime := binary.LittleEndian.Uint64(buf[n:]); n += 8
	e.Timestamp = filetimeToTime(filetime)
	_ = binary.LittleEndian.Uint32(buf[n:]) // flags retained by native diagnostics; omitted from Event v1
	n += 4
	e.IPVersion = binary.LittleEndian.Uint32(buf[n:]); n += 4
	proto := buf[n]; n++
	switch proto {
	case 6:
		e.Protocol = ProtocolTCP
	case 17:
		e.Protocol = ProtocolUDP
	default:
		e.Protocol = ProtocolUnknown
	}
	e.LocalPort = binary.LittleEndian.Uint16(buf[n:]); n += 2
	e.RemotePort = binary.LittleEndian.Uint16(buf[n:]); n += 2
	e.EventCode = binary.LittleEndian.Uint32(buf[n:]); n += 4
	e.Status = binary.LittleEndian.Uint32(buf[n:])
	return e, nil
}

func filetimeToTime(v uint64) time.Time {
	const unixOffset100ns = 116444736000000000
	if v < unixOffset100ns {
		return time.Time{}
	}
	unix100ns := v - unixOffset100ns
	return time.Unix(int64(unix100ns/10_000_000), int64(unix100ns%10_000_000)*100).UTC()
}
