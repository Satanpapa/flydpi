//go:build windows

package runtime

func Events(r *Runtime, limit int) []Event {
	if r == nil { return nil }
	raw := r.PollBatch(limit)
	out := make([]Event, 0, len(raw))
	for _, e := range raw { out = append(out, convert(e)) }
	return out
}
