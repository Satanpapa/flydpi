package probe

import (
	"context"
	"net"
	"sort"
	"time"
)

type DNSResult struct {
	Target       string        `json:"target"`
	SystemAddrs  []string      `json:"system_addrs"`
	Latency      time.Duration `json:"latency"`
	Error        string        `json:"error,omitempty"`
}

// ResolveSystem performs a bounded OS resolver lookup. It deliberately does
// not alter system DNS settings; a separate DoH comparator can be layered on
// top of this result.
func ResolveSystem(ctx context.Context, target string, timeout time.Duration) DNSResult {
	start := time.Now()
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	ips, err := net.DefaultResolver.LookupHost(ctx, target)
	result := DNSResult{Target: target, Latency: time.Since(start)}
	if err != nil {
		result.Error = err.Error()
		return result
	}
	sort.Strings(ips)
	result.SystemAddrs = ips
	return result
}
