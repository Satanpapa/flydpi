package diagnostic

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"
)

type dohAnswer struct { Type int `json:"type"`; Data string `json:"data"` }
type dohResponse struct { Answer []dohAnswer `json:"Answer"` }

// lookupDoH queries a public DNS-over-HTTPS JSON endpoint. It is only used
// as an independent comparison source; it never changes the system resolver.
func lookupDoH(ctx context.Context, client *http.Client, endpoint, hostname string) ([]net.IP, error) {
	u, err := url.Parse(endpoint)
	if err != nil { return nil, err }
	q := u.Query(); q.Set("name", hostname); q.Set("type", "A"); u.RawQuery = q.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil { return nil, err }
	req.Header.Set("Accept", "application/dns-json")
	resp, err := client.Do(req)
	if err != nil { return nil, err }
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK { return nil, fmt.Errorf("doh status %d", resp.StatusCode) }
	var body dohResponse
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil { return nil, err }
	ips := make([]net.IP, 0, len(body.Answer))
	for _, answer := range body.Answer {
		if answer.Type != 1 { continue }
		if ip := net.ParseIP(answer.Data); ip != nil { ips = append(ips, ip) }
	}
	return ips, nil
}

func addressSetsDiffer(a, b []net.IP) bool {
	left := make([]string, 0, len(a)); right := make([]string, 0, len(b))
	for _, ip := range a { left = append(left, ip.String()) }
	for _, ip := range b { right = append(right, ip.String()) }
	sort.Strings(left); sort.Strings(right)
	return !equalStrings(left, right) && len(left) > 0 && len(right) > 0
}

func equalStrings(a, b []string) bool {
	if len(a) != len(b) { return false }
	for i := range a { if a[i] != b[i] { return false } }
	return true
}

func looksLikeNXDOMAIN(err error) bool { return strings.Contains(strings.ToLower(err.Error()), "no such host") }

var defaultDoHEndpoints = []string{
	"https://cloudflare-dns.com/dns-query", // Cloudflare DoH service (1.1.1.1)
	"https://dns.quad9.net/dns-query",
	"https://dns.google/resolve",
}

type dohClient struct { http *http.Client }

func newDoHClient(timeout time.Duration) dohClient {
	return dohClient{http: &http.Client{Timeout: timeout}}
}
