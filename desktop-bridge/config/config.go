package config

import (
	"os"
	"path/filepath"
	"gopkg.in/yaml.v3"
)

// Config holds the application configuration
type Config struct {
	// Auth0 Configuration
	Auth0 Auth0Config `yaml:"auth0"`
	
	// Ollama Configuration
	Ollama OllamaConfig `yaml:"ollama"`
	
	// Cloud Configuration
	Cloud CloudConfig `yaml:"cloud"`
	
	// Bridge Configuration
	Bridge BridgeConfig `yaml:"bridge"`
	
	// Logging Configuration
	Logging LoggingConfig `yaml:"logging"`
}

// Auth0Config holds Auth0 authentication settings
type Auth0Config struct {
	Domain       string   `yaml:"domain"`
	ClientID     string   `yaml:"client_id"`
	Audience     string   `yaml:"audience"`
	Scopes       []string `yaml:"scopes"`
	RedirectURI  string   `yaml:"redirect_uri"`
}

// OllamaConfig holds local Ollama connection settings
type OllamaConfig struct {
	Host    string `yaml:"host"`
	Port    int    `yaml:"port"`
	Timeout int    `yaml:"timeout_seconds"`
}

// CloudConfig holds cloud relay connection settings
type CloudConfig struct {
	WebSocketURL string `yaml:"websocket_url"`
	StatusURL    string `yaml:"status_url"`
	RegisterURL  string `yaml:"register_url"`
}

// BridgeConfig holds bridge-specific settings
type BridgeConfig struct {
	Port         int    `yaml:"port"`
	LogLevel     string `yaml:"log_level"`
	AutoStart    bool   `yaml:"auto_start"`
	ShowTrayIcon bool   `yaml:"show_tray_icon"`
}

// LoggingConfig holds logging settings
type LoggingConfig struct {
	Level    string `yaml:"level"`
	File     string `yaml:"file"`
	MaxSize  int    `yaml:"max_size_mb"`
	MaxAge   int    `yaml:"max_age_days"`
	Compress bool   `yaml:"compress"`
}

// DefaultConfig returns the default configuration
func DefaultConfig() *Config {
	return &Config{
		Auth0: Auth0Config{
			Domain:      "dev-xafu7oedkd5wlrbo.us.auth0.com",
			ClientID:    "ESfES9tnQ4qGxFlwzXpDuRVXCyk0KF29",
			Audience:    "https://app.cloudtolocalllm.online",
			Scopes:      []string{"openid", "profile", "email"},
			RedirectURI: "http://localhost:3025/",
		},
		Ollama: OllamaConfig{
			Host:    "localhost",
			Port:    11434,
			Timeout: 60,
		},
		Cloud: CloudConfig{
			WebSocketURL: "wss://app.cloudtolocalllm.online/ws/bridge",
			StatusURL:    "https://app.cloudtolocalllm.online/api/ollama/bridge/status",
			RegisterURL:  "https://app.cloudtolocalllm.online/api/ollama/bridge/register",
		},
		Bridge: BridgeConfig{
			Port:         3025,
			LogLevel:     "info",
			AutoStart:    false,
			ShowTrayIcon: true,
		},
		Logging: LoggingConfig{
			Level:    "info",
			File:     "",
			MaxSize:  10,
			MaxAge:   30,
			Compress: true,
		},
	}
}

// LoadConfig loads configuration from file or creates default
func LoadConfig() (*Config, error) {
	configPath := getConfigPath()
	
	// Create config directory if it doesn't exist
	configDir := filepath.Dir(configPath)
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return nil, err
	}
	
	// If config file doesn't exist, create default
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		config := DefaultConfig()
		if err := config.Save(); err != nil {
			return nil, err
		}
		return config, nil
	}
	
	// Load existing config
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, err
	}
	
	config := &Config{}
	if err := yaml.Unmarshal(data, config); err != nil {
		return nil, err
	}
	
	return config, nil
}

// Save saves the configuration to file
func (c *Config) Save() error {
	configPath := getConfigPath()
	
	data, err := yaml.Marshal(c)
	if err != nil {
		return err
	}
	
	return os.WriteFile(configPath, data, 0644)
}

// getConfigPath returns the configuration file path
func getConfigPath() string {
	homeDir, _ := os.UserHomeDir()
	return filepath.Join(homeDir, ".config", "cloudtolocalllm", "bridge.yaml")
}

// GetTokenPath returns the path for storing auth tokens
func GetTokenPath() string {
	homeDir, _ := os.UserHomeDir()
	return filepath.Join(homeDir, ".config", "cloudtolocalllm", "tokens.json")
}
