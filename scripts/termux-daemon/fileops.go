package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strconv"
)

const defaultMaxReadBytes int64 = 1 * 1024 * 1024 // 1MB

func handleReadFile(req Request, writeFn func([]byte) error) {
	maxBytes := req.MaxBytes
	if maxBytes <= 0 {
		maxBytes = defaultMaxReadBytes
	}

	info, err := os.Stat(req.Path)
	if err != nil {
		sendError(writeFn, req.ID, fmt.Sprintf("stat failed: %v", err), "STAT_ERROR")
		return
	}

	file, err := os.Open(req.Path)
	if err != nil {
		sendError(writeFn, req.ID, fmt.Sprintf("open failed: %v", err), "OPEN_ERROR")
		return
	}
	defer file.Close()

	// Read up to maxBytes+1 to detect truncation
	buf := make([]byte, maxBytes+1)
	n, err := file.Read(buf)
	if err != nil && err.Error() != "EOF" {
		sendError(writeFn, req.ID, fmt.Sprintf("read failed: %v", err), "READ_ERROR")
		return
	}

	truncated := int64(n) > maxBytes
	readLen := n
	if truncated {
		readLen = int(maxBytes)
	}

	resp := ReadResultResponse{
		Type:      "read_result",
		ID:        req.ID,
		Data:      string(buf[:readLen]),
		Size:      info.Size(),
		Truncated: truncated,
	}
	data, _ := EncodeJSON(resp)
	writeFn(data)
}

func handleWriteFile(req Request, writeFn func([]byte) error) {
	// Ensure parent directory exists
	parent := filepath.Dir(req.Path)
	if err := os.MkdirAll(parent, 0755); err != nil {
		sendError(writeFn, req.ID, fmt.Sprintf("mkdir failed: %v", err), "MKDIR_ERROR")
		return
	}

	flag := os.O_WRONLY | os.O_CREATE | os.O_TRUNC
	if req.Append {
		flag = os.O_WRONLY | os.O_CREATE | os.O_APPEND
	}

	var mode os.FileMode = 0644
	if req.Mode != "" {
		if m, err := strconv.ParseInt(req.Mode, 8, 32); err == nil {
			mode = os.FileMode(m)
		}
	}

	file, err := os.OpenFile(req.Path, flag, mode)
	if err != nil {
		sendError(writeFn, req.ID, fmt.Sprintf("open failed: %v", err), "WRITE_ERROR")
		return
	}
	defer file.Close()

	if _, err := file.WriteString(req.Data); err != nil {
		sendError(writeFn, req.ID, fmt.Sprintf("write failed: %v", err), "WRITE_ERROR")
		return
	}

	resp := WriteResultResponse{
		Type:    "write_result",
		ID:      req.ID,
		Success: true,
	}
	data, _ := EncodeJSON(resp)
	writeFn(data)
}

func handleStat(req Request, writeFn func([]byte) error) {
	info, err := os.Stat(req.Path)
	if err != nil {
		sendError(writeFn, req.ID, fmt.Sprintf("stat failed: %v", err), "STAT_ERROR")
		return
	}

	resp := StatResultResponse{
		Type: "stat_result",
		ID:   req.ID,
		Entry: FileEntry{
			Name:    info.Name(),
			Size:    info.Size(),
			Mode:    info.Mode().String(),
			IsDir:   info.IsDir(),
			ModTime: info.ModTime().Format("2006-01-02T15:04:05Z07:00"),
		},
	}
	data, _ := EncodeJSON(resp)
	writeFn(data)
}

func handleListDir(req Request, writeFn func([]byte) error) {
	entries, err := ioutil.ReadDir(req.Path)
	if err != nil {
		sendError(writeFn, req.ID, fmt.Sprintf("list failed: %v", err), "LIST_ERROR")
		return
	}

	var fileEntries []FileEntry
	for _, entry := range entries {
		fileEntries = append(fileEntries, FileEntry{
			Name:    entry.Name(),
			Size:    entry.Size(),
			Mode:    entry.Mode().String(),
			IsDir:   entry.IsDir(),
			ModTime: entry.ModTime().Format("2006-01-02T15:04:05Z07:00"),
		})
	}

	resp := DirListResponse{
		Type:    "dir_list",
		ID:      req.ID,
		Entries: fileEntries,
	}
	data, _ := EncodeJSON(resp)
	writeFn(data)
}

func sendError(writeFn func([]byte) error, id, message, code string) {
	resp := ErrorResponse{
		Type:    "error",
		ID:      id,
		Message: message,
		Code:    code,
	}
	data, _ := EncodeJSON(resp)
	writeFn(data)
}
