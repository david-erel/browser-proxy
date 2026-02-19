package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

type logEntry struct {
	Timestamp      string `json:"timestamp"`
	URL            string `json:"url"`
	SenderBundleID string `json:"senderBundleId"`
	SenderName     string `json:"senderName"`
	ChosenBrowser  string `json:"chosenBrowser"`
	WasManualChoice bool  `json:"wasManualChoice"`
}

func logEvent(ev urlEvent) {
	cfg := loadConfig()
	logPath := expandHome(cfg.LogFile)

	os.MkdirAll(filepath.Dir(logPath), 0755)

	f, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "browser-proxy: failed to open log file: %v\n", err)
		return
	}
	defer f.Close()

	entry := logEntry{
		Timestamp:       time.Now().UTC().Format(time.RFC3339),
		URL:             ev.URL,
		SenderBundleID:  ev.SenderBundleID,
		SenderName:      ev.SenderName,
		ChosenBrowser:   ev.ChosenBrowser,
		WasManualChoice: ev.WasManual,
	}

	data, err := json.Marshal(entry)
	if err != nil {
		fmt.Fprintf(os.Stderr, "browser-proxy: failed to marshal log entry: %v\n", err)
		return
	}

	f.Write(data)
	f.Write([]byte("\n"))
}
