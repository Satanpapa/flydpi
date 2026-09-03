package strategy

import "testing"

func TestRankPrefersCorrelationWhenResetsAndTimeoutsExist(t *testing.T) {
	ranked := Rank(Observation{RSTs: 2, Timeouts: 2, TLSErrors: 1})
	if len(ranked) == 0 {
		t.Fatal("expected candidates")
	}
	if ranked[0].Candidate.ID != "reset_timeout_correlation" {
		t.Fatalf("top candidate = %q, want reset_timeout_correlation", ranked[0].Candidate.ID)
	}
}

func TestRankIsDeterministic(t *testing.T) {
	obs := Observation{IPv4Success: 3, IPv6Success: 1, QUICSeen: 2}
	a := Rank(obs)
	b := Rank(obs)
	if len(a) != len(b) {
		t.Fatal("rank lengths differ")
	}
	for i := range a {
		if a[i].Candidate.ID != b[i].Candidate.ID || a[i].Value != b[i].Value {
			t.Fatalf("rank is not deterministic at index %d", i)
		}
	}
}
