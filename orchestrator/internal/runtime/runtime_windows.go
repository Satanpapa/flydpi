//go:build windows

package runtime

import (
	"fmt"
	"syscall"
	"unsafe"
)

type runtimeEvent struct {
	TimestampUnixMs uint64
	Kind            uint32
	Protocol        uint32
	RemotePort      uint16
	_                uint16
	ProcessID       uint32
	LatencyMs       uint64
	ErrorCode       int32
	Reserved        uint32
}

type Runtime struct {
	dll       *syscall.DLL
	start     *syscall.Proc
	lastError *syscall.Proc
	poll      *syscall.Proc
	stop      *syscall.Proc
	rt        uintptr
}

func Open(coreDLL, observerDLL string) (*Runtime, error) {
	dll, err := syscall.LoadDLL(coreDLL)
	if err != nil {
		return nil, fmt.Errorf("load core dll: %w", err)
	}
	start, err := dll.FindProc("flydpi_runtime_start")
	if err != nil {
		_ = dll.Release()
		return nil, fmt.Errorf("runtime start symbol: %w", err)
	}
	lastError, err := dll.FindProc("flydpi_runtime_last_error_code")
	if err != nil {
		_ = dll.Release()
		return nil, fmt.Errorf("runtime error symbol: %w", err)
	}
	poll, err := dll.FindProc("flydpi_runtime_poll")
	if err != nil {
		_ = dll.Release()
		return nil, fmt.Errorf("runtime poll symbol: %w", err)
	}
	stop, err := dll.FindProc("flydpi_runtime_stop")
	if err != nil {
		_ = dll.Release()
		return nil, fmt.Errorf("runtime stop symbol: %w", err)
	}

	path, err := syscall.BytePtrFromString(observerDLL)
	if err != nil {
		_ = dll.Release()
		return nil, fmt.Errorf("observer path: %w", err)
	}
	ret, _, callErr := start.Call(uintptr(unsafe.Pointer(path)))
	if ret == 0 {
		code, _, _ := lastError.Call()
		_ = dll.Release()
		return nil, fmt.Errorf("runtime start failed (code %d): %s", code, describeStartError(uint32(code), callErr))
	}
	return &Runtime{dll: dll, start: start, lastError: lastError, poll: poll, stop: stop, rt: ret}, nil
}

func describeStartError(code uint32, fallback error) string {
	switch {
	case code == 0:
		if fallback != syscall.Errno(0) {
			return fallback.Error()
		}
		return "unknown startup failure"
	case code == 1:
		return "unsupported platform"
	case code == 2:
		return "invalid observer DLL path"
	case code == 3:
		return "failed to load observer DLL"
	case code == 4:
		return "required observer entry point is missing"
	case code == 5:
		return "failed to start WFP ingest worker"
	case code >= 0x10000000:
		return fmt.Sprintf("WFP observer start failed with Win32 code %d", code-0x10000000)
	default:
		return fmt.Sprintf("startup error code %d", code)
	}
}

func (r *Runtime) Poll() (runtimeEvent, bool, error) {
	var event runtimeEvent
	ret, _, _ := r.poll.Call(r.rt, uintptr(unsafe.Pointer(&event)))
	switch ret {
	case 1:
		return event, true, nil
	case 0:
		return runtimeEvent{}, false, nil
	default:
		return runtimeEvent{}, false, fmt.Errorf("runtime poll returned %d", ret)
	}
}

func (r *Runtime) PollBatch(limit int) []runtimeEvent {
	if limit <= 0 {
		return nil
	}
	if limit > 256 {
		limit = 256
	}
	out := make([]runtimeEvent, 0, limit)
	for len(out) < limit {
		event, ok, err := r.Poll()
		if err != nil || !ok {
			break
		}
		out = append(out, event)
	}
	return out
}

func (r *Runtime) Close() {
	if r == nil {
		return
	}
	if r.rt != 0 {
		r.stop.Call(r.rt)
		r.rt = 0
	}
	if r.dll != nil {
		_ = r.dll.Release()
		r.dll = nil
	}
}
