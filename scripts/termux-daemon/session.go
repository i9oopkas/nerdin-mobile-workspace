package main

import (
	"fmt"
	"io"
	"os/exec"
	"sync"
	"time"
)

type UserSession struct {
	ID        string
	Cmd       string
	Pty       bool
	CreatedAt time.Time
	Cancel    func()
	CmdObj    *exec.Cmd
	Stdin     io.WriteCloser
	Stdout    io.ReadCloser
	Stderr    io.ReadCloser
}

type SessionManager struct {
	mu       sync.Mutex
	sessions map[string]*UserSession
}

func NewSessionManager() *SessionManager {
	return &SessionManager{
		sessions: make(map[string]*UserSession),
	}
}

func (sm *SessionManager) Create(id, cmd string, writeFn func([]byte) error) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if _, exists := sm.sessions[id]; exists {
		return fmt.Errorf("session %s already exists", id)
	}

	return nil
}

func (sm *SessionManager) Kill(id string) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, ok := sm.sessions[id]
	if !ok {
		return fmt.Errorf("session %s not found", id)
	}

	if session.Cancel != nil {
		session.Cancel()
	}
	delete(sm.sessions, id)
	return nil
}

func (sm *SessionManager) List() []SessionInfo {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	var list []SessionInfo
	for id, session := range sm.sessions {
		list = append(list, SessionInfo{
			ID:        id,
			Cmd:       session.Cmd,
			Status:    "running",
			StartedAt: session.CreatedAt.Format(time.RFC3339),
		})
	}
	return list
}
