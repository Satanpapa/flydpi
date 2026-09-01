package probe

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"time"
)

type Config struct {
	Timeout      time.Duration
	Targets      []string
	Port         string
	ServerName   string
}

type Result struct {
	Target        string        `json:"target"`
	TCPConnected  bool          `json:"tcp_connected"`
	TLSHandshake  bool          `json:"tls_handshake"`
	Latency       time.Duration `json:"latency"`
	Error         string        `json:"error,omitempty"`
}

func Run(ctx context.Context, cfg Config) []Result {
	results := make([]Result, 0, len(cfg.Targets))
	for _, target := range cfg.Targets {
		results = append(results, runOne(ctx, cfg, target))
	}
	return results
}

func runOne(parent context.Context, cfg Config, target string) Result {
	result := Result{Target: target}
	ctx, cancel := context.WithTimeout(parent, cfg.Timeout)
	defer cancel()

	port := cfg.Port
	if port == "" {
		port = "443"
	}
	addr := net.JoinHostPort(target, port)
	start := time.Now()

	d := net.Dialer{}
	conn, err := d.DialContext(ctx, "tcp", addr)
	if err != nil {
		result.Error = err.Error()
		return result
	}
	result.TCPConnected = true
	result.Latency = time.Since(start)
	defer conn.Close()

	serverName := cfg.ServerName
	if serverName == "" {
		serverName = target
	}
	deadline := time.Now().Add(cfg.Timeout)
	_ = conn.SetDeadline(deadline)
	tlsConn := tls.Client(conn, &tls.Config{
		ServerName:         serverName,
		MinVersion:         tls.VersionTLS12,
		InsecureSkipVerify: true, // probe only; certificate validation is separate
	})
	if err := tlsConn.HandshakeContext(ctx); err != nil {
		result.Error = fmt.Sprintf("tls handshake: %v", err)
		return result
	}
	result.TLSHandshake = true
	return result
}
