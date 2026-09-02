package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
)

func main() {
	root, err := os.Executable()
	if err != nil {
		fatal(err)
	}
	root = filepath.Dir(root)

	backendPath := filepath.Join(root, "bin", "flydpi.exe")
	guiPath := filepath.Join(root, "ui", "flydpi-ui.exe")

	if _, err := os.Stat(backendPath); err != nil {
		fatal(fmt.Errorf("backend not found: %w", err))
	}
	if _, err := os.Stat(guiPath); err != nil {
		fatal(fmt.Errorf("GUI not found: %w", err))
	}

	backend := exec.Command(backendPath)
	backend.Dir = root
	backend.Stdout = nil
	backend.Stderr = nil
	backend.Stdin = nil
	if err := backend.Start(); err != nil {
		fatal(fmt.Errorf("start backend: %w", err))
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
