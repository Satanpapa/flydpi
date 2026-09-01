package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Satanpapa/flydpi/orchestrator/internal/diagnostic"
	"github.com/Satanpapa/flydpi/orchestrator/internal/rpc"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	engine := diagnostic.NewEngine(diagnostic.Config{
		Targets: []string{"example.com", "t.me", "youtube.com"},
		Port: "443",
		Timeout: 2 * time.Second,
		Concurrency: 4,
	})
	server := rpc.NewServer(engine)

	log.Println("FlyDPI diagnostic orchestrator listening on 127.0.0.1:27654")
	if err := rpc.ListenLoop(ctx, "127.0.0.1:27654", server.Handle); err != nil && ctx.Err() == nil {
		log.Fatal(err)
	}
}
