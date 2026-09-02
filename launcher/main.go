package main

import (
    "errors"
    "fmt"
    "net"
    "os"
    "os/exec"
    "os/signal"
    "path/filepath"
    "syscall"
    "time"
)

const rpcAddr = "127.0.0.1:27654"

func main() {
    root, err := os.Executable()
    if err != nil {
        fatal(err)
    }
    root = filepath.Dir(root)

    backendPath := filepath.Join(root, "bin", "flydpi.exe")
    guiPath := filepath.Join(root, "ui", "flydpi-ui.exe")
    logDir := filepath.Join(root, "logs")

    if _, err := os.Stat(backendPath); err != nil {
        fatal(fmt.Errorf("backend not found: %w", err))
    }
    if _, err := os.Stat(guiPath); err != nil {
        fatal(fmt.Errorf("GUI not found: %w", err))
    }
    if err := os.MkdirAll(logDir, 0o700); err != nil {
        fatal(fmt.Errorf("create log directory: %w", err))
    }

    backendLog, err := os.OpenFile(filepath.Join(logDir, "backend.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
    if err != nil {
        fatal(fmt.Errorf("open backend log: %w", err))
    }
    defer backendLog.Close()

    backend := exec.Command(backendPath)
    backend.Dir = root
    backend.Stdout = backendLog
    backend.Stderr = backendLog
    backend.Stdin = nil
    if err := backend.Start(); err != nil {
        fatal(fmt.Errorf("start backend: %w", err))
    }

    if err := waitForBackend(backend, 10*time.Second); err != nil {
        _ = terminate(backend)
        _ = backend.Wait()
        fatal(err)
    }

    gui := exec.Command(guiPath, os.Args[1:]...)
    gui.Dir = root
    gui.Stdout = os.Stdout
    gui.Stderr = os.Stderr
    gui.Stdin = os.Stdin

    stop := make(chan os.Signal, 1)
    signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
    go func() {
        <-stop
        _ = terminate(backend)
    }()

    err = gui.Run()
    _ = terminate(backend)
    _ = backend.Wait()

    if err != nil {
        if errors.Is(err, syscall.EINTR) {
            return
        }
        fatal(fmt.Errorf("GUI exited with error: %w", err))
    }
}

func waitForBackend(backend *exec.Cmd, timeout time.Duration) error {
    deadline := time.Now().Add(timeout)
    for time.Now().Before(deadline) {
        if backend.ProcessState != nil && backend.ProcessState.Exited() {
            return fmt.Errorf("backend exited before RPC became ready; see logs\\backend.log")
        }

        conn, err := net.DialTimeout("tcp", rpcAddr, 250*time.Millisecond)
        if err == nil {
            _ = conn.Close()
            return nil
        }
        time.Sleep(100 * time.Millisecond)
    }
    return fmt.Errorf("backend RPC did not become ready at %s; see logs\\backend.log", rpcAddr)
}

func terminate(cmd *exec.Cmd) error {
    if cmd == nil || cmd.Process == nil {
        return nil
    }
    return cmd.Process.Kill()
}

func fatal(err error) {
    fmt.Fprintln(os.Stderr, "FlyDPI:", err)
    os.Exit(1)
}
