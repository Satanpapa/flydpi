package profile

import (
    "encoding/json"
    "errors"
    "os"
    "path/filepath"
    "sort"
    "strings"
    "time"
)

type Profile struct {
    SchemaVersion int      `json:"schema_version"`
    Name          string   `json:"name"`
    PreferredAction string `json:"preferred_action"`
    Mode          string   `json:"mode"`
    TimeoutMS     int      `json:"timeout_ms"`
    Targets       []string `json:"targets"`
    LastSeverity  string   `json:"last_severity"`
    UpdatedAt     time.Time `json:"updated_at"`
}

type Store struct { dir string }

func NewStore(dir string) *Store { return &Store{dir: dir} }

func DefaultDir() string {
    base, err := os.UserConfigDir()
    if err != nil { return "profiles" }
    return filepath.Join(base, "DpiBypass", "profiles")
}

func (s *Store) Save(p Profile) error {
    if strings.TrimSpace(p.Name) == "" { return errors.New("profile name required") }
    if p.SchemaVersion == 0 { p.SchemaVersion = 1 }
    if p.UpdatedAt.IsZero() { p.UpdatedAt = time.Now().UTC() }
    if err := os.MkdirAll(s.dir, 0o700); err != nil { return err }
    data, err := json.MarshalIndent(p, "", "  ")
    if err != nil { return err }
    return os.WriteFile(filepath.Join(s.dir, sanitize(p.Name)+".json"), append(data, '\n'), 0o600)
}

func (s *Store) List() ([]Profile, error) {
    entries, err := os.ReadDir(s.dir)
    if err != nil {
        if os.IsNotExist(err) { return []Profile{}, nil }
        return nil, err
    }
    profiles := make([]Profile, 0)
    for _, e := range entries {
        if e.IsDir() || filepath.Ext(e.Name()) != ".json" { continue }
        b, err := os.ReadFile(filepath.Join(s.dir, e.Name()))
        if err != nil { return nil, err }
        var p Profile
        if json.Unmarshal(b, &p) == nil { profiles = append(profiles, p) }
    }
    sort.Slice(profiles, func(i, j int) bool { return profiles[i].Name < profiles[j].Name })
    return profiles, nil
}

func sanitize(name string) string {
    name = strings.TrimSpace(name)
    var b strings.Builder
    for _, r := range name {
        switch {
        case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9', r == '-', r == '_': b.WriteRune(r)
        default: b.WriteRune('_')
        }
    }
    if b.Len() == 0 { return "profile" }
    return b.String()
}
