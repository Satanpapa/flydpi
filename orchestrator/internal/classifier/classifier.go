package classifier

import "time"

type Features struct {
	RSTDetected       bool `json:"rst_detected"`
	PoisoningDetected bool `json:"poisoning_detected"`
	TimeoutDetected   bool `json:"timeout_detected"`
	FragWorks         bool `json:"frag_works"`
	SNISpoofWorks     bool `json:"sni_spoof_works"`
}

type Probe struct {
	Hostname   string        `json:"hostname"`
	Mode       string        `json:"mode"`
	Success    bool          `json:"success"`
	RST        bool          `json:"rst_detected"`
	Timeout    bool          `json:"timeout_detected"`
	Duration   time.Duration `json:"duration_ns"`
	ErrorClass string        `json:"error_class,omitempty"`
}

type Classification struct {
	Features        Features `json:"features"`
	PreferredTactic string   `json:"preferred_tactic"`
	Confidence      float64  `json:"confidence"`
	Reason          string   `json:"reason"`
}

// Classify maps observable probe symptoms to a diagnostic profile. It never
// mutates traffic or installs networking policy.
func Classify(probes []Probe) Classification {
	var f Features
	for _, p := range probes {
		f.RSTDetected = f.RSTDetected || p.RST
		f.TimeoutDetected = f.TimeoutDetected || p.Timeout
	}

	switch {
	case f.RSTDetected && f.TimeoutDetected:
		return Classification{Features: f, PreferredTactic: "fragmentation_policy", Confidence: 0.82, Reason: "reset and timeout symptoms observed"}
	case f.RSTDetected:
		return Classification{Features: f, PreferredTactic: "fragmentation_policy", Confidence: 0.74, Reason: "reset observed during probe"}
	case f.TimeoutDetected:
		return Classification{Features: f, PreferredTactic: "diagnostic_manual", Confidence: 0.55, Reason: "timeout observed without confirmed reset"}
	default:
		return Classification{Features: f, PreferredTactic: "none", Confidence: 0.90, Reason: "no blocking symptom observed"}
	}
}
