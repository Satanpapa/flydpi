package probe

import (
	"context"
	"encoding/json"
	"net"
	"sync"
	"time"
)

type EngineConfig struct {
	Targets      []string      `json:"targets"`
	Port         string        `json:"port"`
	Timeout      time.Duration `json:"timeout_ns"`
	Concurrency  int           `json:"concurrency"`
}

type Engine struct{ cfg EngineConfig }

func NewEngine(cfg EngineConfig) *Engine {
	if cfg.Port == "" { cfg.Port = "443" }
	if cfg.Timeout <= 0 { cfg.Timeout = 2 * time.Second }
	if cfg.Concurrency <= 0 { cfg.Concurrency = 8 }
	return &Engine{cfg: cfg}
}

func (e *Engine) Run(ctx context.Context) []Result {
	type item struct{ idx int; target string }
	jobs := make(chan item)
	results := make([]Result, len(e.cfg.Targets))
	workers := e.cfg.Concurrency
	if workers > len(e.cfg.Targets) { workers = len(e.cfg.Targets) }
	if workers == 0 { return results }

	var wg sync.WaitGroup
	wg.Add(workers)
	for i := 0; i < workers; i++ {
		go func() {
			defer wg.Done()
			for job := range jobs {
				results[job.idx] = runOne(ctx, Config{Timeout: e.cfg.Timeout, Port: e.cfg.Port, Targets: []string{job.target}}, job.target)
			}
		}()
	}
	for i, target := range e.cfg.Targets { jobs <- item{i, target} }
	close(jobs)
	wg.Wait()
	return results
}

func (e *Engine) RunJSON(ctx context.Context) ([]byte, error) {
	return json.Marshal(e.Run(ctx))
}

// IsPrivateTarget rejects probe destinations that resolve to local/private
// networks. This prevents an accidental diagnostic profile from scanning
// RFC1918, loopback, or link-local endpoints.
func IsPrivateTarget(ip net.IP) bool {
	return ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsPrivate()
}
