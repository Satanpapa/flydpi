package rpc

import (
    "context"
    "encoding/json"
    "fmt"
    "net"
    "sync/atomic"
    "time"

    "github.com/Satanpapa/flydpi/orchestrator/internal/diagnostic"
    "github.com/Satanpapa/flydpi/orchestrator/internal/history"
    "github.com/Satanpapa/flydpi/orchestrator/internal/profile"
    runtimebridge "github.com/Satanpapa/flydpi/orchestrator/internal/runtime"
)

type Server struct {
    seq uint64
    engine *diagnostic.Engine
    profiles *profile.Store
    history *history.Store
    runtime *runtimebridge.Manager
}

type Request struct { JSONRPC string `json:"jsonrpc"`; ID uint64 `json:"id"`; Method string `json:"method"`; Params json.RawMessage `json:"params,omitempty"` }
type Response struct { JSONRPC string `json:"jsonrpc"`; ID uint64 `json:"id"`; Result interface{} `json:"result,omitempty"`; Error *RPCError `json:"error,omitempty"` }
type RPCError struct { Code int `json:"code"`; Message string `json:"message"` }

func NewServer(engine *diagnostic.Engine, profiles *profile.Store, history *history.Store, runtime *runtimebridge.Manager) *Server {
    return &Server{engine: engine, profiles: profiles, history: history, runtime: runtime}
}

func (s *Server) Handle(ctx context.Context, req Request) Response {
    if req.JSONRPC != "2.0" { return Response{JSONRPC:"2.0", ID:req.ID, Error:&RPCError{-32600,"invalid request"}} }
    switch req.Method {
    case "status.get":
        runtimeState := map[string]interface{}{"enabled": false}
        if s.runtime != nil { runtimeState["enabled"] = s.runtime.Enabled(); runtimeState["error"] = s.runtime.Error() }
        return Response{JSONRPC:"2.0", ID:req.ID, Result:map[string]interface{}{"state":"ready","sequence":atomic.LoadUint64(&s.seq),"runtime":runtimeState}}
    case "telemetry.poll":
        limit := 32
        var params struct { Limit int `json:"limit"` }
        if len(req.Params) > 0 { _ = json.Unmarshal(req.Params, &params); if params.Limit > 0 { limit = params.Limit } }
        if limit > 128 { limit = 128 }
        var events interface{} = []runtimebridge.Event{}
        if s.runtime != nil { events = s.runtime.Events(limit) }
        return Response{JSONRPC:"2.0", ID:req.ID, Result:events}
    case "diagnostic.run", "probe.run":
        atomic.AddUint64(&s.seq,1)
        report := s.engine.Run(ctx)
        _ = s.history.Add(history.Entry{Timestamp: report.FinishedAt, Severity: string(report.Severity), Title: report.Title, Summary: report.Explanation})
        return Response{JSONRPC:"2.0",ID:req.ID,Result:report}
    case "history.list":
        items, err := s.history.List(); if err != nil { return Response{JSONRPC:"2.0",ID:req.ID,Error:&RPCError{-32020,err.Error()}} }
        return Response{JSONRPC:"2.0",ID:req.ID,Result:items}
    case "profile.list":
        items, err := s.profiles.List(); if err != nil { return Response{JSONRPC:"2.0",ID:req.ID,Error:&RPCError{-32021,err.Error()}} }
        return Response{JSONRPC:"2.0",ID:req.ID,Result:items}
    case "profile.save":
        var p profile.Profile
        if err:=json.Unmarshal(req.Params,&p); err != nil { return Response{JSONRPC:"2.0",ID:req.ID,Error:&RPCError{-32602,"invalid profile"}} }
        if err:=s.profiles.Save(p); err != nil { return Response{JSONRPC:"2.0",ID:req.ID,Error:&RPCError{-32022,err.Error()}} }
        return Response{JSONRPC:"2.0",ID:req.ID,Result:map[string]bool{"saved":true}}
    default:
        return Response{JSONRPC:"2.0", ID:req.ID, Error:&RPCError{-32601, fmt.Sprintf("method %q not found", req.Method)}}
    }
}

func ListenLoop(ctx context.Context, addr string, handler func(context.Context, Request) Response) error {
    ln, err := net.Listen("tcp", addr); if err != nil { return err }
    defer ln.Close()
    for {
        _ = ln.(*net.TCPListener).SetDeadline(time.Now().Add(500*time.Millisecond))
        conn, err := ln.Accept()
        if err != nil { if ne,ok:=err.(net.Error); ok && ne.Timeout() { select { case <-ctx.Done(): return ctx.Err(); default: continue } }; return err }
        go func(c net.Conn){ defer c.Close(); dec:=json.NewDecoder(c); enc:=json.NewEncoder(c); var req Request; if err:=dec.Decode(&req); err == nil { _=enc.Encode(handler(ctx,req)) } }(conn)
    }
}
