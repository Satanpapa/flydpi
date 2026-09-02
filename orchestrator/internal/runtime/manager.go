package runtime

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
)

type Manager struct {
	mu sync.Mutex
	rt *Runtime
	err error
}

func NewManager(baseDir string) *Manager {
	m := &Manager{}
	if baseDir == "" { return m }
	core := filepath.Join(baseDir, "bin", "flydpi-core.dll")
	observer := filepath.Join(baseDir, "bin", "flydpi_wfp_observer.dll")
	if _, err := os.Stat(core); err != nil { m.err = fmt.Errorf("core runtime unavailable: %w", err); return m }
	if _, err := os.Stat(observer); err != nil { m.err = fmt.Errorf("WFP observer unavailable: %w", err); return m }
	rt, err := Open(core, observer)
	if err != nil { m.err = err; return m }
	m.rt = rt
	return m
}

func (m *Manager) Enabled() bool {
	m.mu.Lock(); defer m.mu.Unlock()
	return m.rt != nil
}

func (m *Manager) Error() string {
	m.mu.Lock(); defer m.mu.Unlock()
	if m.err == nil { return "" }
	return m.err.Error()
}

func (m *Manager) Events(limit int) []Event {
	m.mu.Lock(); defer m.mu.Unlock()
	if m.rt == nil { return nil }
	return Events(m.rt, limit)
}

func (m *Manager) Close() {
	m.mu.Lock(); defer m.mu.Unlock()
	if m.rt != nil { m.rt.Close(); m.rt = nil }
}
