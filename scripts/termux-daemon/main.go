package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"strings"
	"sync/atomic"
	"syscall"
	"time"
)

var (
	port      = flag.Int("port", 64735, "TCP port to listen on")
	startTime = time.Now()
	clientID  int64
)

func main() {
	flag.Parse()

	addr := fmt.Sprintf("127.0.0.1:%d", *port)
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatalf("Failed to listen on %s: %v", addr, err)
	}
	defer listener.Close()

	log.Printf("Termux Daemon listening on %s", addr)

	execManager := NewExecManager()
	sessionManager := NewSessionManager()

	// Signal handling for graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		<-sigCh
		log.Println("Shutting down...")
		listener.Close()
		os.Exit(0)
	}()

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("Accept error: %v", err)
			continue
		}

		id := atomic.AddInt64(&clientID, 1)
		log.Printf("Client %d connected from %s", id, conn.RemoteAddr())

		go handleClient(conn, id, execManager, sessionManager)
	}
}

func handleClient(conn net.Conn, id int64, execManager *ExecManager, sessionManager *SessionManager) {
	defer conn.Close()

	writeFn := func(data []byte) error {
		_, err := conn.Write(data)
		if err != nil {
			return err
		}
		_, err = conn.Write([]byte("\n"))
		return err
	}

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 256*1024), 512*1024) // 256KB initial, 512KB max

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		var req Request
		if err := json.Unmarshal([]byte(line), &req); err != nil {
			sendError(writeFn, "", fmt.Sprintf("invalid JSON: %v", err), "PARSE_ERROR")
			continue
		}

		dispatch(req, writeFn, execManager, sessionManager)
	}

	log.Printf("Client %d disconnected", id)
}

func dispatch(req Request, writeFn func([]byte) error, execManager *ExecManager, sessionManager *SessionManager) {
	switch req.Type {
	case "exec":
		execManager.Start(req, writeFn)

	case "exec_input":
		err := execManager.SendInput(req.ID, req.Data, req.Close)
		if err != nil {
			sendError(writeFn, req.ID, err.Error(), "INPUT_ERROR")
		}

	case "exec_signal":
		err := execManager.SendSignal(req.ID, req.Signal)
		if err != nil {
			sendError(writeFn, req.ID, err.Error(), "SIGNAL_ERROR")
		}

	case "read_file":
		handleReadFile(req, writeFn)

	case "write_file":
		handleWriteFile(req, writeFn)

	case "stat":
		handleStat(req, writeFn)

	case "list_dir":
		handleListDir(req, writeFn)

	case "session":
		handleSession(req, writeFn, sessionManager)

	case "ping":
		resp := PongResponse{
			Type:    "pong",
			Version: "0.1.0",
			Uptime:  time.Since(startTime).Round(time.Second).String(),
		}
		data, _ := EncodeJSON(resp)
		writeFn(data)

	case "shutdown":
		log.Printf("Shutdown requested by client")
		resp := BaseResponse{Type: "shutdown_ack", ID: req.ID}
		data, _ := EncodeJSON(resp)
		writeFn(data)
		go func() {
			time.Sleep(100 * time.Millisecond)
			os.Exit(0)
		}()

	default:
		sendError(writeFn, req.ID, fmt.Sprintf("unknown request type: %s", req.Type), "UNKNOWN_TYPE")
	}
}

func handleSession(req Request, writeFn func([]byte) error, sm *SessionManager) {
	switch req.Action {
	case "list":
		sessions := sm.List()
		resp := SessionListResponse{
			Type:     "session_list",
			ID:       req.ID,
			Sessions: sessions,
		}
		data, _ := EncodeJSON(resp)
		writeFn(data)

	case "kill":
		if req.SessionID == "" {
			sendError(writeFn, req.ID, "session_id required", "MISSING_FIELD")
			return
		}
		err := sm.Kill(req.SessionID)
		if err != nil {
			sendError(writeFn, req.ID, err.Error(), "KILL_ERROR")
			return
		}
		resp := BaseResponse{Type: "session_killed", ID: req.ID}
		data, _ := EncodeJSON(resp)
		writeFn(data)

	default:
		sendError(writeFn, req.ID, fmt.Sprintf("unknown session action: %s", req.Action), "UNKNOWN_ACTION")
	}
}
