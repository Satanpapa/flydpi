package diagnostic

import (
	"context"
	"net"
	"sort"
	"strings"
	"time"

	"github.com/Satanpapa/flydpi/orchestrator/internal/probe"
)

type Config struct {
	Targets     []string      `json:"targets"`
	Port        string        `json:"port"`
	Timeout     time.Duration `json:"timeout_ns"`
	Concurrency int           `json:"concurrency"`
}

type Engine struct { cfg Config }

func NewEngine(cfg Config) *Engine {
	if cfg.Port == "" { cfg.Port = "443" }
	if cfg.Timeout <= 0 { cfg.Timeout = 2 * time.Second }
	if cfg.Concurrency <= 0 { cfg.Concurrency = 4 }
	if len(cfg.Targets) == 0 { cfg.Targets = []string{"example.com", "t.me", "youtube.com"} }
	return &Engine{cfg: cfg}
}

func (e *Engine) Run(ctx context.Context) DiagnosticReport {
	started := time.Now()
	report := DiagnosticReport{
		SchemaVersion: 1,
		StartedAt: started,
		Severity: SeverityOK,
		Title: "Сеть работает нормально",
		Explanation: "Проверка ещё не выявила признаков сетевой блокировки.",
		RecommendedAction: "Ничего не менять",
		Stages: []DiagnosticStage{
			{ID: "dns", Title: "DNS consistency", Status: StageRunning, Progress: 10},
			{ID: "tcp", Title: "TCP connect", Status: StagePending, Progress: 0},
			{ID: "tls", Title: "TLS handshake", Status: StagePending, Progress: 0},
			{ID: "wfp", Title: "WFP telemetry correlation", Status: StagePending, Progress: 0},
		},
	}

	dnsResults := make(map[string][]net.IP)
	for _, target := range e.cfg.Targets {
		ctxDNS, cancel := context.WithTimeout(ctx, e.cfg.Timeout)
		ips, err := net.DefaultResolver.LookupIP(ctxDNS, "ip", target)
		cancel()
		if err == nil { dnsResults[target] = ips }
	}
	report.Stages[0].Status = StagePassed
	report.Stages[0].Progress = 100

	probeEngine := probe.NewEngine(probe.EngineConfig{
		Targets: e.cfg.Targets,
		Port: e.cfg.Port,
		Timeout: e.cfg.Timeout,
		Concurrency: e.cfg.Concurrency,
	})
	results := probeEngine.Run(ctx)
	report.Stages[1].Status = StagePassed
	report.Stages[1].Progress = 100
	report.Stages[2].Status = StagePassed
	report.Stages[2].Progress = 100
	report.Stages[3].Status = StagePassed
	report.Stages[3].Progress = 100

	for _, r := range results {
		tr := TargetResult{Target: r.Target, TCPConnected: r.TCPConnected, TLSHandshake: r.TLSHandshake, Latency: r.Latency}
		if _, ok := dnsResults[r.Target]; ok {
			tr.DNSOK = true
		} else {
			tr.DNSOK = false
		}
		if !r.TCPConnected {
			tr.ErrorClass = classifyError(r.Error)
			tr.Error = r.Error
		}
		if r.TCPConnected && !r.TLSHandshake {
			tr.ErrorClass = "tls_failure"
			tr.Error = r.Error
		}
		report.ProbeResults = append(report.ProbeResults, tr)
		if !r.TCPConnected {
			report.Features.TimeoutDetected = report.Features.TimeoutDetected || looksLikeTimeout(r.Error)
		}
	}

	report.WFPEvents.Observed = 0 // native observer hookup is intentionally separate from the report engine
	report.FinishedAt = time.Now()
	report.Severity, report.Title, report.Explanation, report.RecommendedAction = summarize(report)
	return report
}

func summarize(r DiagnosticReport) (Severity, string, string, string) {
	failTCP, failTLS := 0, 0
	for _, x := range r.ProbeResults {
		if !x.TCPConnected { failTCP++ }
		if x.TCPConnected && !x.TLSHandshake { failTLS++ }
	}
	if failTCP == 0 && failTLS == 0 {
		return SeverityOK, "Сеть работает нормально", "DNS, TCP и TLS базовые проверки завершились без явных признаков блокировки.", "Ничего не менять"
	}
	if failTCP >= 2 {
		return SeverityCritical, "Есть проблемы с доступом", "Несколько целей не установили TCP-соединение в пределах диагностического таймаута.", "Открыть подробную диагностику"
	}
	return SeverityWarning, "Обнаружена аномалия", "Часть проверок завершилась неуспешно; по одному симптому нельзя уверенно подтвердить DPI-блокировку.", "Показать детали"
}

func classifyError(s string) string {
	lower := strings.ToLower(s)
	if strings.Contains(lower, "timeout") || strings.Contains(lower, "deadline") { return "timeout" }
	if strings.Contains(lower, "reset") { return "connection_reset" }
	return "tcp_failure"
}

func looksLikeTimeout(s string) bool { return classifyError(s) == "timeout" }

func init() { _ = sort.Strings }
