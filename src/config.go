package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
)

type Rule struct {
	SenderName     string `json:"senderName,omitempty"`
	SenderBundleID string `json:"senderBundleId,omitempty"`
	Browser        string `json:"browser"`
}

type Config struct {
	DefaultBrowser string `json:"defaultBrowser"`
	LogFile        string `json:"logFile"`
	Rules          []Rule `json:"rules"`
}

func configDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "browser-proxy")
}

func logDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Library", "Logs", "browser-proxy")
}

func configPath() string {
	return filepath.Join(configDir(), "config.json")
}

func expandHome(path string) string {
	if strings.HasPrefix(path, "~/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, path[2:])
	}
	return path
}

func loadConfig() Config {
	cfg := Config{
		DefaultBrowser: "chrome",
		LogFile:        filepath.Join(logDir(), "url.log"),
	}

	data, err := os.ReadFile(configPath())
	if err != nil {
		os.MkdirAll(configDir(), 0755)
		writeConfig(cfg)
		return cfg
	}

	defaultLogFile := cfg.LogFile
	json.Unmarshal(data, &cfg)

	if cfg.LogFile == "" {
		cfg.LogFile = defaultLogFile
	}

	cfg.DefaultBrowser = strings.ToLower(cfg.DefaultBrowser)
	if cfg.DefaultBrowser != "chrome" && cfg.DefaultBrowser != "firefox" {
		cfg.DefaultBrowser = "chrome"
	}

	return cfg
}

func (cfg Config) resolveBrowser(senderName, senderBundleID string) string {
	senderNameLower := strings.ToLower(senderName)
	senderBundleLower := strings.ToLower(senderBundleID)
	for _, r := range cfg.Rules {
		if r.SenderName != "" && strings.ToLower(r.SenderName) == senderNameLower {
			return strings.ToLower(r.Browser)
		}
		if r.SenderBundleID != "" && strings.ToLower(r.SenderBundleID) == senderBundleLower {
			return strings.ToLower(r.Browser)
		}
	}
	return cfg.DefaultBrowser
}

func writeConfig(cfg Config) {
	data, _ := json.MarshalIndent(cfg, "", "  ")
	os.WriteFile(configPath(), data, 0644)
}
