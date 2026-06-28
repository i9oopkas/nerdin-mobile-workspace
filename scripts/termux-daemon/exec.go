package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"sync"
	"syscall"
	"time"
)

type ExecSession struct {
	ID       string
	Cmd      string
	Workdir  string
	Env      map[string]string
	Cancel   context.CancelFunc
	CmdObj   *exec.Cmd
	Stdin    io.WriteCloser
	StdoutW  *io.PipeWriter
	StderrW  *io.PipeWriter
	Mu       sync.Mutex
	Complete chan struct{}
}

type ExecManager struct {
	mu       sync.Mutex
	sessions map[string]*ExecSession
	seq      int
}

func NewExecManager() *ExecManager {
	return &ExecManager{
		sessions: make(map[string]*ExecSession),
	}
}

func (em *ExecManager) Start(req Request, writeFn func([]byte) error) {
	ctx, cancel := context.WithCancel(context.Background())

	shell := os.Getenv("SHELL")
	if shell == "" {
		shell = "/data/data/com.termux/files/usr/bin/bash"
	}

	cmd := exec.CommandContext(ctx, shell, "-c", req.Cmd)

	if req.Workdir != "" {
		cmd.Dir = req.Workdir
	}

	// Set up environment
	cmd.Env = os.Environ()
	for k, v := range req.Env {
		cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", k, v))
	}

	// Create pipes
	stdin, _ := cmd.StdinPipe()
	stdout, _ := cmd.StdoutPipe()
	stderr, _ := cmd.StderrPipe()

	session := &ExecSession{
		ID:       req.ID,
		Cmd:      req.Cmd,
		Workdir:  req.Workdir,
		Env:      req.Env,
		Cancel:   cancel,
		CmdObj:   cmd,
		Stdin:    stdin,
		Complete: make(chan struct{}),
	}

	em.mu.Lock()
	em.sessions[req.ID] = session
	em.mu.Unlock()

	// Stream stdout
	go func() {
		scanner := bufio.NewScanner(stdout)
		scanner.Buffer(make([]byte, 64*1024), 1024*1024)
		for scanner.Scan() {
			em.mu.Lock()
			em.seq++
			seq := em.seq
			em.mu.Unlock()

			resp := StdoutResponse{
				Type: "stdout",
				ID:   req.ID,
				Data: scanner.Text() + "\n",
				Seq:  seq,
			}
			data, _ := EncodeJSON(resp)
			writeFn(data)
		}
	}()

	// Stream stderr
	go func() {
		scanner := bufio.NewScanner(stderr)
		scanner.Buffer(make([]byte, 64*1024), 1024*1024)
		for scanner.Scan() {
			em.mu.Lock()
			em.seq++
			seq := em.seq
			em.mu.Unlock()

			resp := StderrResponse{
				Type: "stderr",
				ID:   req.ID,
				Data: scanner.Text() + "\n",
				Seq:  seq,
			}
			data, _ := EncodeJSON(resp)
			writeFn(data)
		}
	}()

	// Wait for completion
	go func() {
		defer close(session.Complete)

		err := cmd.Run()
		exitCode := 0
		signalName := ""

		if err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok {
				exitCode = exitErr.ExitCode()
				if status, ok := exitErr.Sys().(syscall.WaitStatus); ok {
					if status.Signaled() {
						signalName = fmt.Sprintf("SIG%s", strings.TrimPrefix(status.Signal().String(), "signal "))
					}
				}
			} else {
				exitCode = -1
			}
		}

		resp := ExitResponse{
			Type:   "exit",
			ID:     req.ID,
			Code:   exitCode,
			Signal: signalName,
		}
		data, _ := EncodeJSON(resp)
		writeFn(data)

		em.mu.Lock()
		delete(em.sessions, req.ID)
		em.mu.Unlock()
	}()
}

func (em *ExecManager) SendInput(id, data string, closeStdin bool) error {
	em.mu.Lock()
	session, ok := em.sessions[id]
	em.mu.Unlock()

	if !ok {
		return fmt.Errorf("session %s not found", id)
	}

	session.Mu.Lock()
	defer session.Mu.Unlock()

	if session.Stdin == nil {
		return fmt.Errorf("stdin closed for session %s", id)
	}

	if data != "" {
		if _, err := io.WriteString(session.Stdin, data); err != nil {
			return fmt.Errorf("write stdin: %w", err)
		}
	}

	if closeStdin {
		if err := session.Stdin.Close(); err != nil {
			return fmt.Errorf("close stdin: %w", err)
		}
		session.Stdin = nil
	}

	return nil
}

func (em *ExecManager) SendSignal(id, signal string) error {
	em.mu.Lock()
	session, ok := em.sessions[id]
	em.mu.Unlock()

	if !ok {
		return fmt.Errorf("session %s not found", id)
	}

	var sig os.Signal
	switch strings.ToUpper(signal) {
	case "SIGTERM":
		sig = syscall.SIGTERM
	case "SIGINT":
		sig = syscall.SIGINT
	case "SIGKILL":
		sig = syscall.SIGKILL
	case "SIGHUP":
		sig = syscall.SIGHUP
	default:
		return fmt.Errorf("unsupported signal: %s", signal)
	}

	return session.CmdObj.Process.Signal(sig)
}

func (em *ExecManager) List() []SessionInfo {
	em.mu.Lock()
	defer em.mu.Unlock()

	var list []SessionInfo
	for id, session := range em.sessions {
		status := "running"
		select {
		case <-session.Complete:
			status = "completed"
		default:
		}
		list = append(list, SessionInfo{
			ID:        id,
			Cmd:       session.Cmd,
			Status:    status,
			StartedAt: time.Now().Format(time.RFC3339),
		})
	}
	return list
}
