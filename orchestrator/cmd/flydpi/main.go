package main

import (
    "context"
    "log"
    "os"
    "os/signal"
    "path/filepath"
    "syscall"
    "time"

    "github.com/Satanpapa/flydpi/orchestrator/internal/diagnostic"
    "github.com/Satanpapa/flydpi/orchestrator/internal/history"
    "github.com/Satanpapa/flydpi/orchestrator/internal/profile"
    runtimebridge "github.com/Satanpapa/flydpi/orchestrator/internal/runtime"
    "github.com/Satanpapa/flydpi/orchestrator/internal/rpc"
)

func main() {
    ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
    defer stop()

    engine := diagnostic.NewEngine(diagnostic.Config{Targets: []string{"example.com", "t.me", "youtube.com"}, Port: "443", Timeout: 2 * time.Second, Concurrency: 4})

    base := profile.DefaultDir()
    historyDir := filepath.Join(filepath.Dir(base), "history")
    profiles := profile.NewStore(base)
    historyStore := history.NewStore(historyDir, 100)

    exe, err := os.Executable()
    if err != nil { log.Fatal(err) }
    runtimeBase := filepath.Dir(filepath.Dir(exe))
    runtimeManager := runtimebridge.NewManager(runtimeBase)
    defer runtimeManager.Close()

    server := rpc.NewServer(engine, profiles, historyStore, runtimeManager)

    log.Println("FlyDPI diagnostic orchestrator listening on 127.0.0.1:27654")
    if err := rpc.ListenLoop(ctx, "127.0.0.1:27654", server.Handle); err != nil && ctx.Err() == nil { log.Fatal(err) }
}
