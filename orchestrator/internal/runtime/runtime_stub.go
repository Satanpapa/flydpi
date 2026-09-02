//go:build !windows

package runtime

import "fmt"

type runtimeEvent struct {
	TimestampUnixMs uint64
	Kind            uint32
	Protocol        uint32
	RemotePort      uint16
	ProcessID       uint32
	LatencyMs       uint64
	ErrorCode       int32
}

type Runtime struct{}

func Open(_, _ string) (*Runtime, error) { return nil, fmt.Errorf("FlyDPI runtime is Windows-only") }
func (r *Runtime) PollBatch(_ int) []runtimeEvent { return nil }
func (r *Runtime) Close() {}
