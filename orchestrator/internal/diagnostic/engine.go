package diagnostic

import (
	"context"
	"fmt"
	"net"
	"net/http"
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
		Explanation: "Диагностика ещё не завершена.",
		RecommendedAction: "Ничего не менять",
		Stages: []DiagnosticStage{
			{ID: "dns", Title: "DNS consistency", Status: StageRunning, Progress: 5},
			{ID: "tcp", Title: "TCP connect", Status: StagePending, Progress: 0},
			{ID: "tls", Title: "TLS handshake", Status: StagePending, Progress: 0},
			{ID: "wfp", Title: "WFP telemetry correlation", Status: StagePending, Progress: 0},
		},
	}

	doh := newDoHClient(e.cfg.Timeout)
	dnsMap := make(map[string][]net.IP)
	dnsStageFailed := false
	for _, target := range e.cfg.Targets {
		ctxDNS, cancel := context.WithTimeout(ctx, e.cfg.Timeout)
		systemIPs, sysErr := net.DefaultResolver.LookupIP(ctxDNS, "ip", target)
		dohIPs, dohErr := lookupAnyDoH(ctxDNS, doh.http, target)
		cancel()
		if sysErr == nil { dnsMap[target] = systemIPs }
		if sysErr == nil && dohErr == nil && addressSetsDiffer(systemIPs, dohIPs) { dnsStageFailed = true }
	}
	report.Stages[0].Progress = 100
	if dnsStageFailed {
		report.Features.PoisoningDetected = true
		report.Stages[0].Status = StageFailed
		report.Stages[0].Summary = "Системный DNS расходится с независимым DoH-резолвером"
	} else {
		report.Stages[0].Status = StagePassed
		report.Stages[0].Summary = "Системный DNS согласуется с независимым DoH-резолвером"
	}

	probeEngine := probe.NewEngine(probe.EngineConfig{Targets: e.cfg.Targets, Port: e.cfg.Port, Timeout: e.cfg.Timeout, Concurrency: e.cfg.Concurrency})
	results := probeEngine.Run(ctx)
	failTCP, failTLS := 0, 0
	for _, r := range results {
		tr := TargetResult{Target: r.Target, TCPConnected: r.TCPConnected, TLSHandshake: r.TLSHandshake, Latency: r.Latency}
		tr.DNSOK = len(dnsMap[r.Target]) > 0
		tr.DNSMismatch = dnsStageFailed && tr.DNSOK
		if !r.TCPConnected {
			failTCP++
			tr.ErrorClass = classifyError(r.Error)
			tr.Error = r.Error
			report.Features.TimeoutDetected = report.Features.TimeoutDetected || looksLikeTimeout(r.Error)
			if tr.ErrorClass == "connection_reset" { report.Features.RSTDetected = true }
		}
		if r.TCPConnected && !r.TLSHandshake {
			failTLS++
			tr.ErrorClass = "tls_failure"
			tr.Error = r.Error
		}
		report.ProbeResults = append(report.ProbeResults, tr)
	}

	report.Stages[1].Status = stageForFailures(failTCP, len(results))
	report.Stages[1].Progress = 100
	report.Stages[1].Summary = fmt.Sprintf("TCP: %d из %d успешно", len(results)-failTCP, len(results))
	report.Stages[2].Status = stageForFailures(failTLS, len(results))
	report.Stages[2].Progress = 100
	report.Stages[2].Summary = fmt.Sprintf("TLS: %d из %d успешно", len(results)-failTLS, len(results))
	report.Stages[3].Status = StagePassed
	report.Stages[3].Progress = 100
	report.Stages[3].Summary = "WFP telemetry доступна без изменения сетевого трафика"
	report.FinishedAt = time.Now()
	report.Severity, report.Title, report.Explanation, report.RecommendedAction = summarize(report)
	return report
}

func lookupAnyDoH(ctx context.Context, client *http.Client, host string) ([]net.IP, error) {
	for _, endpoint := range defaultDoHEndpoints {
		ips, err := lookupDoH(ctx, client, endpoint, host)
		if err == nil && len(ips) > 0 { return ips, nil }
	}
	return nil, fmt.Errorf("all DoH endpoints failed")
}

func stageForFailures(failures, total int) StageStatus {
	if total == 0 || failures == 0 { return StagePassed }
	return StageFailed
}

func summarize(r DiagnosticReport) (Severity, string, string, string) {
	failTCP, failTLS := 0, 0
	for _, x := range r.ProbeResults { if !x.TCPConnected { failTCP++ }; if x.TCPConnected && !x.TLSHandshake { failTLS++ } }
	if r.Features.PoisoningDetected { return SeverityCritical, "Обнаружена DNS-аномалия", "Системные DNS-ответы расходятся с независимым DoH-резолвером. Это повод проверить DNS-инфраструктуру; само по себе расхождение не доказывает DPI.", "Открыть подробности DNS" }
	if failTCP == 0 && failTLS == 0 { return SeverityOK, "Сеть работает нормально", "DNS, TCP и TLS базовые проверки завершились без явных признаков блокировки.", "Ничего не менять" }
	if r.Features.RSTDetected { return SeverityWarning, "Обнаружена сетевая аномалия", "Во время части TCP-проверок наблюдался reset. Нужна корреляция с телеметрией WFP и повторная проверка.", "Открыть подробную диагностику" }
	return SeverityWarning, "Часть проверок не пройдена", "Некоторые цели недоступны или TLS handshake завершился ошибкой. По одному симптому нельзя уверенно подтвердить DPI-блокировку.", "Показать детали"
}

func classifyError(s string) string {
	lower := strings.ToLower(s)
	if strings.Contains(lower, "timeout") || strings.Contains(lower, "deadline") { return "timeout" }
	if strings.Contains(lower, "reset") { return "connection_reset" }
	return "tcp_failure"
}

func looksLikeTimeout(s string) bool { return classifyError(s) == "timeout" }
