//go:build !windows

package runtime

func Events(_ *Runtime, _ int) []Event { return nil }
