package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Satanpapa/flydpi/orchestrator/internal/probe"
	"github.com/Satanpapa/flydpi/orchestrator/internal/rpc"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	engine := probe.NewEngine(probe.EngineConfig{
		Targets:     []string{"example.com", "t.me", "youtube.com"},
		Port:        "443",
		Timeout:     2 * time.Second,
		Concurrency: 4,
	})
	server := rpc.NewServer(engine)

	log.Println("FlyDPI orchestrator listening on 127.0.0.1:27654")
	if err := rpc.ListenLoop(ctx, "127.0.0.1:27654", server.Handle); err != nil && ctx.Err() == nil {
		log.Fatal(err)
	}
}
