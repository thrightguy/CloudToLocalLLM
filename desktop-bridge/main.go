package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"github.com/sirupsen/logrus"
	"cloudtolocalllm-bridge/auth"
	"cloudtolocalllm-bridge/config"
	"cloudtolocalllm-bridge/tray"
	"cloudtolocalllm-bridge/tunnel"
)

const (
	AppName    = "CloudToLocalLLM Bridge"
	AppVersion = "1.0.0"
)

func main() {
	// Parse command line flags
	var (
		showVersion = flag.Bool("version", false, "Show version information")
		showHelp    = flag.Bool("help", false, "Show help information")
		configPath  = flag.String("config", "", "Path to configuration file")
		logLevel    = flag.String("log-level", "", "Log level (debug, info, warn, error)")
		noTray      = flag.Bool("no-tray", false, "Run without system tray (headless mode)")
		daemon      = flag.Bool("daemon", false, "Run as daemon (implies --no-tray)")
	)
	flag.Parse()

	if *showVersion {
		fmt.Printf("%s v%s\n", AppName, AppVersion)
		os.Exit(0)
	}

	if *showHelp {
		showUsage()
		os.Exit(0)
	}

	// Initialize logger
	logger := logrus.New()
	logger.SetFormatter(&logrus.TextFormatter{
		FullTimestamp: true,
	})

	// Load configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		logger.Fatalf("Failed to load configuration: %v", err)
	}

	// Override config with command line flags
	if *logLevel != "" {
		cfg.Bridge.LogLevel = *logLevel
	}

	// Set log level
	level, err := logrus.ParseLevel(cfg.Bridge.LogLevel)
	if err != nil {
		logger.Warnf("Invalid log level '%s', using 'info'", cfg.Bridge.LogLevel)
		level = logrus.InfoLevel
	}
	logger.SetLevel(level)

	// Set up log file if configured
	if cfg.Logging.File != "" {
		logFile, err := setupLogFile(cfg.Logging.File)
		if err != nil {
			logger.Warnf("Failed to setup log file: %v", err)
		} else {
			logger.SetOutput(logFile)
			defer logFile.Close()
		}
	}

	logger.Infof("Starting %s v%s", AppName, AppVersion)

	// Create application context
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-sigChan
		logger.Infof("Received signal %v, shutting down...", sig)
		cancel()
	}()

	// Initialize components
	authManager := auth.NewAuthManager(cfg, logger)
	tunnelManager := tunnel.NewTunnelManager(cfg, logger, authManager)

	// Load existing tokens
	if err := authManager.LoadTokens(); err != nil {
		logger.Warnf("Failed to load tokens: %v", err)
	}

	// Check if running in daemon mode
	if *daemon {
		*noTray = true
		logger.Info("Running in daemon mode")
	}

	if *noTray {
		// Run in headless mode
		runHeadless(ctx, logger, authManager, tunnelManager)
	} else {
		// Run with system tray
		runWithTray(ctx, logger, cfg, authManager, tunnelManager)
	}
}

// runHeadless runs the application without system tray
func runHeadless(ctx context.Context, logger *logrus.Logger, authMgr *auth.AuthManager, tunnelMgr *tunnel.TunnelManager) {
	logger.Info("Running in headless mode")

	// Check authentication
	if !authMgr.IsAuthenticated() {
		logger.Error("Not authenticated. Please run with system tray to login, or use the web interface.")
		os.Exit(1)
	}

	// Start tunnel
	if err := tunnelMgr.Start(ctx); err != nil {
		logger.Fatalf("Failed to start tunnel: %v", err)
	}

	logger.Info("Bridge started successfully")

	// Wait for context cancellation
	<-ctx.Done()

	logger.Info("Shutting down...")
	tunnelMgr.Stop()
}

// runWithTray runs the application with system tray
func runWithTray(ctx context.Context, logger *logrus.Logger, cfg *config.Config, authMgr *auth.AuthManager, tunnelMgr *tunnel.TunnelManager) {
	logger.Info("Starting with system tray")

	// Create tray manager
	trayManager := tray.NewTrayManager(cfg, logger, authMgr, tunnelMgr)

	// Handle context cancellation
	go func() {
		<-ctx.Done()
		logger.Info("Context cancelled, stopping tray...")
		trayManager.Stop()
	}()

	// Run tray (this blocks until tray exits)
	trayManager.Run()

	logger.Info("Tray exited, shutting down...")
	tunnelMgr.Stop()
}

// setupLogFile sets up log file with rotation
func setupLogFile(logPath string) (*os.File, error) {
	// Create log directory if it doesn't exist
	logDir := filepath.Dir(logPath)
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return nil, err
	}

	// Open log file
	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return nil, err
	}

	return logFile, nil
}

// showUsage shows command line usage
func showUsage() {
	fmt.Printf(`%s v%s

A secure bridge connecting your local Ollama instance to the CloudToLocalLLM cloud service.

Usage:
  cloudtolocalllm-bridge [options]

Options:
  --version           Show version information
  --help              Show this help message
  --config PATH       Path to configuration file
  --log-level LEVEL   Set log level (debug, info, warn, error)
  --no-tray           Run without system tray (headless mode)
  --daemon            Run as daemon (implies --no-tray)

Examples:
  # Run with system tray (default)
  cloudtolocalllm-bridge

  # Run in headless mode
  cloudtolocalllm-bridge --no-tray

  # Run as daemon with debug logging
  cloudtolocalllm-bridge --daemon --log-level debug

Configuration:
  Configuration file is automatically created at:
  ~/.config/cloudtolocalllm/bridge.yaml

  Authentication tokens are stored at:
  ~/.config/cloudtolocalllm/tokens.json

For more information, visit: https://cloudtolocalllm.online
`, AppName, AppVersion)
}
