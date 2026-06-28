package main

import "encoding/json"

// ---- Request Types ----

type Request struct {
	Type      string            `json:"type"`
	ID        string            `json:"id"`
	Cmd       string            `json:"cmd,omitempty"`
	Workdir   string            `json:"workdir,omitempty"`
	Env       map[string]string `json:"env,omitempty"`
	Timeout   int               `json:"timeout,omitempty"`
	Data      string            `json:"data,omitempty"`
	Close     bool              `json:"close,omitempty"`
	Signal    string            `json:"signal,omitempty"`
	Path      string            `json:"path,omitempty"`
	MaxBytes  int64             `json:"max_bytes,omitempty"`
	Mode      string            `json:"mode,omitempty"`
	Append    bool              `json:"append,omitempty"`
	Action    string            `json:"action,omitempty"`
	SessionID string            `json:"session_id,omitempty"`
}

// ---- Response Types ----

type BaseResponse struct {
	Type string `json:"type"`
	ID   string `json:"id"`
}

type StdoutResponse struct {
	Type string `json:"type"`
	ID   string `json:"id"`
	Data string `json:"data"`
	Seq  int    `json:"seq"`
}

type StderrResponse struct {
	Type string `json:"type"`
	ID   string `json:"id"`
	Data string `json:"data"`
	Seq  int    `json:"seq"`
}

type ExitResponse struct {
	Type   string `json:"type"`
	ID     string `json:"id"`
	Code   int    `json:"code"`
	Signal string `json:"signal,omitempty"`
}

type ReadResultResponse struct {
	Type      string `json:"type"`
	ID        string `json:"id"`
	Data      string `json:"data"`
	Size      int64  `json:"size"`
	Truncated bool   `json:"truncated"`
}

type WriteResultResponse struct {
	Type    string `json:"type"`
	ID      string `json:"id"`
	Success bool   `json:"success"`
	Error   string `json:"error,omitempty"`
}

type FileEntry struct {
	Name    string `json:"name"`
	Size    int64  `json:"size"`
	Mode    string `json:"mode"`
	IsDir   bool   `json:"is_dir"`
	ModTime string `json:"mod_time"`
}

type StatResultResponse struct {
	Type  string    `json:"type"`
	ID    string    `json:"id"`
	Entry FileEntry `json:"entry"`
}

type DirListResponse struct {
	Type    string      `json:"type"`
	ID      string      `json:"id"`
	Entries []FileEntry `json:"entries"`
}

type SessionInfo struct {
	ID        string `json:"id"`
	Cmd       string `json:"cmd"`
	Status    string `json:"status"`
	StartedAt string `json:"started_at"`
}

type SessionCreatedResponse struct {
	Type      string `json:"type"`
	ID        string `json:"id"`
	SessionID string `json:"session_id"`
}

type SessionListResponse struct {
	Type     string        `json:"type"`
	ID       string        `json:"id"`
	Sessions []SessionInfo `json:"sessions"`
}

type PongResponse struct {
	Type    string `json:"type"`
	Version string `json:"version"`
	Uptime  string `json:"uptime"`
}

type ErrorResponse struct {
	Type    string `json:"type"`
	ID      string `json:"id"`
	Message string `json:"message"`
	Code    string `json:"code"`
}

// Encode helpers
func EncodeJSON(v interface{}) ([]byte, error) {
	return json.Marshal(v)
}
