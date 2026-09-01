package profile

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type Features struct {
	RSTDetected       bool `json:"rst_detected"`
	PoisoningDetected bool `json:"poisoning_detected"`
	TimeoutDetected   bool `json:"timeout_detected"`
	FragWorks         bool `json:"frag_works"`
	SNISpoofWorks     bool `json:"sni_spoof_works"`
}

type Profile struct {
	SchemaVersion    int      `json:"schema_version"`
	ProfileName      string   `json:"profile_name"`
	PreferredTactic  string   `json:"preferred_tactic"`
	AttemptTimeoutMS int      `json:"attempt_timeout_ms"`
	ProbeTimeoutMS   int      `json:"probe_timeout_ms"`
	TestDomains      []string `json:"test_domains"`
	Features         Features `json:"features"`
}

func Save(dir string, p Profile) error {
	if p.SchemaVersion == 0 {
		p.SchemaVersion = 1
	}
	if p.ProfileName == "" {
		return fmt.Errorf("profile_name is required")
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(p, "", "  ")
	if err != nil {
		return err
	}
	path := filepath.Join(dir, filepath.Base(p.ProfileName)+".json")
	return os.WriteFile(path, append(data, '\n'), 0o600)
}
