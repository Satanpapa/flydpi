package probe

import (
	"context"
	"net"
	"testing"
	"time"
)

func TestRunConnectFailureIsBounded(t *testing.T) {
	port := freePort(t)
	ctx := context.Background()
	results := Run(ctx, Config{
		Timeout: 200 * time.Millisecond,
		Targets: []string{"127.0.0.1"},
		Port:    port,
	})
	if len(results) != 1 {
		t.Fatalf("got %d results", len(results))
	}
	if results[0].TCPConnected {
		t.Fatalf("unexpected connection to unused test port")
	}
}

func freePort(t *testing.T) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil { t.Fatal(err) }
	defer ln.Close()
	return net.TCPAddrFromAddr(ln.Addr()).String()[len("127.0.0.1:"):]
}
