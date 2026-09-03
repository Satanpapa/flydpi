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

// Classify maps observable symptoms to a safe diagnostic profile. It never
// mutates traffic, installs firewall policy, or applies packet transformations.
func Classify(probes []Probe) Classification {
	var f Features
	for _, p := range probes {
		f.RSTDetected = f.RSTDetected || p.RST
		f.TimeoutDetected = f.TimeoutDetected || p.Timeout
	}

	switch {
	case f.RSTDetected && f.TimeoutDetected:
		return Classification{Features: f, PreferredTactic: "correlate_rst_timeout", Confidence: 0.82, Reason: "reset and timeout symptoms observed; correlate transport and WFP telemetry"}
	case f.RSTDetected:
		return Classification{Features: f, PreferredTactic: "repeat_tcp_matrix", Confidence: 0.74, Reason: "reset observed; repeat across targets and address families"}
	case f.TimeoutDetected:
		return Classification{Features: f, PreferredTactic: "repeat_timeout_matrix", Confidence: 0.55, Reason: "timeout observed without confirmed reset"}
	default:
		return Classification{Features: f, PreferredTactic: "baseline", Confidence: 0.90, Reason: "no blocking symptom observed"}
	}
}
