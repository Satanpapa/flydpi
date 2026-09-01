package history

import (
    "encoding/json"
    "os"
    "path/filepath"
    "sort"
    "time"
)

type Entry struct {
    ID        string      `json:"id"`
    Timestamp time.Time   `json:"timestamp"`
    Severity  string      `json:"severity"`
    Title     string      `json:"title"`
    Summary   string      `json:"summary"`
}

type Store struct { dir string; limit int }

func NewStore(dir string, limit int) *Store {
    if limit <= 0 { limit = 100 }
    return &Store{dir: dir, limit: limit}
}

func (s *Store) Add(e Entry) error {
    if e.Timestamp.IsZero() { e.Timestamp = time.Now().UTC() }
    if e.ID == "" { e.ID = e.Timestamp.Format("20060102-150405.000000000") }
    if err := os.MkdirAll(s.dir, 0o700); err != nil { return err }
    b, err := json.MarshalIndent(e, "", "  ")
    if err != nil { return err }
    if err := os.WriteFile(filepath.Join(s.dir, e.ID+".json"), append(b, '\n'), 0o600); err != nil { return err }
    entries, err := os.ReadDir(s.dir)
    if err != nil { return err }
    type fileInfo struct { path string; mod time.Time }
    files := make([]fileInfo, 0)
    for _, f := range entries {
        if f.IsDir() || filepath.Ext(f.Name()) != ".json" { continue }
        info, err := f.Info(); if err != nil { continue }
        files = append(files, fileInfo{filepath.Join(s.dir, f.Name()), info.ModTime()})
    }
    sort.Slice(files, func(i,j int) bool { return files[i].mod.Before(files[j].mod) })
    for len(files) > s.limit { _ = os.Remove(files[0].path); files = files[1:] }
    return nil
}

func (s *Store) List() ([]Entry, error) {
    entries, err := os.ReadDir(s.dir)
    if err != nil { if os.IsNotExist(err) { return []Entry{}, nil }; return nil, err }
    out := make([]Entry, 0)
    for _, f := range entries {
        if f.IsDir() || filepath.Ext(f.Name()) != ".json" { continue }
        b, err := os.ReadFile(filepath.Join(s.dir, f.Name())); if err != nil { continue }
        var e Entry
        if json.Unmarshal(b, &e) == nil { out = append(out, e) }
    }
    sort.Slice(out, func(i,j int) bool { return out[i].Timestamp.After(out[j].Timestamp) })
    if len(out) > s.limit { out = out[:s.limit] }
    return out, nil
}
