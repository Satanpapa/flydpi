package diagnostic

import "time"

type Severity string

const (
	SeverityOK       Severity = "ok"
	SeverityWarning  Severity = "warning"
	SeverityCritical Severity = "critical"
)

type StageStatus string

const (
	StagePending StageStatus = "pending"
	StageRunning StageStatus = "running"
	StagePassed  StageStatus = "passed"
	StageFailed  StageStatus = "failed"
)

type DiagnosticStage struct {
	ID         string        `json:"id"`
	Title      string        `json:"title"`
	Status     StageStatus   `json:"status"`
	Progress   int           `json:"progress"`
	Duration   time.Duration `json:"duration_ns"`
	Summary    string        `json:"summary,omitempty"`
	Details    []string      `json:"details,omitempty"`
}

type DiagnosticReport struct {
	SchemaVersion int               `json:"schema_version"`
	StartedAt     time.Time         `json:"started_at"`
	FinishedAt    time.Time         `json:"finished_at"`
	Severity      Severity          `json:"severity"`
	Title         string            `json:"title"`
	Explanation   string            `json:"explanation"`
	RecommendedAction string         `json:"recommended_action"`
	Stages        []DiagnosticStage `json:"stages"`
	Features      Features          `json:"features"`
	ProbeResults  []TargetResult    `json:"probe_results"`
	WFPEvents     WFPEventSummary   `json:"wfp_events"`
}

type Features struct {
	RSTDetected       bool `json:"rst_detected"`
	PoisoningDetected bool `json:"poisoning_detected"`
	TimeoutDetected   bool `json:"timeout_detected"`
	FragWorks         bool `json:"frag_works"`
	SNISpoofWorks     bool `json:"sni_spoof_works"`
}

type TargetResult struct {
	Target       string        `json:"target"`
	DNSOK        bool          `json:"dns_ok"`
	DNSMismatch  bool          `json:"dns_mismatch"`
	TCPConnected bool          `json:"tcp_connected"`
	TLSHandshake bool          `json:"tls_handshake"`
	Latency      time.Duration `json:"latency_ns"`
	ErrorClass   string        `json:"error_class,omitempty"`
	Error        string        `json:"error,omitempty"`
}

type WFPEventSummary struct {
	Observed       uint64 `json:"observed"`
	ResetLike      uint64 `json:"reset_like"`
	TimeoutLike    uint64 `json:"timeout_like"`
	ClassifyDrops  uint64 `json:"classify_drops"`
}
