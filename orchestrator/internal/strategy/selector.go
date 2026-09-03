package strategy

import (
	"math"
	"sort"
)

// Candidate describes a diagnostic strategy. The selector intentionally
// contains only observation/probe choices; it does not describe packet
// mutation, injection, fragmentation, spoofing, or firewall changes.
type Candidate struct {
	ID          string
	Description string
	Risk        string
	Weight      float64
}

// Observation captures facts available from the current passive pipeline.
type Observation struct {
	TCPFailures      int
	TLSErrors        int
	RSTs             int
	Timeouts         int
	DNSAvailabilityMismatch int
	IPv4Success      int
	IPv6Success      int
	QUICSeen         int
}

type Score struct {
	Candidate Candidate
	Value     float64
	Reason    string
}

var candidates = []Candidate{
	{ID: "baseline", Description: "Повторить базовую TCP/TLS проверку", Risk: "low", Weight: 1.0},
	{ID: "address_family_matrix", Description: "Сравнить IPv4 и IPv6", Risk: "low", Weight: 0.95},
	{ID: "reset_timeout_correlation", Description: "Сопоставить reset/timeout с WFP telemetry", Risk: "low", Weight: 0.9},
	{ID: "tls_matrix", Description: "Повторить TLS-проверку по нескольким целям", Risk: "low", Weight: 0.9},
	{ID: "quic_observation", Description: "Проверить наличие QUIC long-header traffic", Risk: "low", Weight: 0.8},
}

// Rank returns deterministic, explainable diagnostic candidates.
func Rank(o Observation) []Score {
	scores := make([]Score, 0, len(candidates))
	for _, c := range candidates {
		value := c.Weight
		reason := "базовый контрольный сценарий"

		switch c.ID {
		case "address_family_matrix":
			if o.IPv4Success != o.IPv6Success {
				value += 1.5
				reason = "IPv4/IPv6 дают разные результаты"
			} else {
				reason = "проверка симметрии address family"
			}
		case "reset_timeout_correlation":
			value += math.Min(float64(o.RSTs)*0.8, 2.0)
			value += math.Min(float64(o.Timeouts)*0.5, 1.5)
			if o.RSTs > 0 || o.Timeouts > 0 {
				reason = "обнаружены transport failure symptoms"
			}
		case "tls_matrix":
			value += math.Min(float64(o.TLSErrors)*0.7, 2.0)
			if o.TLSErrors > 0 {
				reason = "TLS ошибки требуют повторного сравнения"
			}
		case "quic_observation":
			value += math.Min(float64(o.QUICSeen)*0.4, 1.5)
			if o.QUICSeen > 0 {
				reason = "наблюдался QUIC traffic"
			}
		}

		scores = append(scores, Score{Candidate: c, Value: value, Reason: reason})
	}

	sort.SliceStable(scores, func(i, j int) bool {
		if scores[i].Value == scores[j].Value {
			return scores[i].Candidate.ID < scores[j].Candidate.ID
		}
		return scores[i].Value > scores[j].Value
	})
	return scores
}
