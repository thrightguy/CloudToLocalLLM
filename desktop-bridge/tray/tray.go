package tray

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"time"

	"github.com/getlantern/systray"
	"github.com/sirupsen/logrus"
	"cloudtolocalllm-bridge/auth"
	"cloudtolocalllm-bridge/config"
	"cloudtolocalllm-bridge/tunnel"
)

// TrayManager manages the system tray interface
type TrayManager struct {
	config        *config.Config
	logger        *logrus.Logger
	authManager   *auth.AuthManager
	tunnelManager *tunnel.TunnelManager
	
	// Menu items
	statusItem     *systray.MenuItem
	connectItem    *systray.MenuItem
	disconnectItem *systray.MenuItem
	loginItem      *systray.MenuItem
	logoutItem     *systray.MenuItem
	settingsItem   *systray.MenuItem
	aboutItem      *systray.MenuItem
	quitItem       *systray.MenuItem
	
	// Context for operations
	ctx    context.Context
	cancel context.CancelFunc
}

// NewTrayManager creates a new tray manager
func NewTrayManager(cfg *config.Config, logger *logrus.Logger, authMgr *auth.AuthManager, tunnelMgr *tunnel.TunnelManager) *TrayManager {
	ctx, cancel := context.WithCancel(context.Background())
	
	return &TrayManager{
		config:        cfg,
		logger:        logger,
		authManager:   authMgr,
		tunnelManager: tunnelMgr,
		ctx:           ctx,
		cancel:        cancel,
	}
}

// Run starts the system tray
func (t *TrayManager) Run() {
	systray.Run(t.onReady, t.onExit)
}

// Stop stops the tray manager
func (t *TrayManager) Stop() {
	t.cancel()
	systray.Quit()
}

// onReady is called when the system tray is ready
func (t *TrayManager) onReady() {
	t.logger.Info("System tray initialized")
	
	// Set tray icon and tooltip
	systray.SetIcon(getIconData())
	systray.SetTitle("CloudToLocalLLM Bridge")
	systray.SetTooltip("CloudToLocalLLM Desktop Bridge")
	
	// Create menu items
	t.createMenuItems()
	
	// Start status update loop
	go t.statusUpdateLoop()
	
	// Start menu event handler
	go t.handleMenuEvents()
	
	// Update initial status
	t.updateStatus()
}

// onExit is called when the system tray is exiting
func (t *TrayManager) onExit() {
	t.logger.Info("System tray exiting")
	t.cancel()
}

// createMenuItems creates the tray menu items
func (t *TrayManager) createMenuItems() {
	// Status item (non-clickable)
	t.statusItem = systray.AddMenuItem("Status: Initializing...", "Current bridge status")
	t.statusItem.Disable()
	
	systray.AddSeparator()
	
	// Connection controls
	t.connectItem = systray.AddMenuItem("Connect", "Connect to cloud relay")
	t.disconnectItem = systray.AddMenuItem("Disconnect", "Disconnect from cloud relay")
	
	systray.AddSeparator()
	
	// Authentication controls
	t.loginItem = systray.AddMenuItem("Login", "Login to Auth0")
	t.logoutItem = systray.AddMenuItem("Logout", "Logout and clear tokens")
	
	systray.AddSeparator()
	
	// Settings and info
	t.settingsItem = systray.AddMenuItem("Settings", "Open settings")
	t.aboutItem = systray.AddMenuItem("About", "About CloudToLocalLLM Bridge")
	
	systray.AddSeparator()
	
	// Quit
	t.quitItem = systray.AddMenuItem("Quit", "Quit the application")
}

// handleMenuEvents handles menu item clicks
func (t *TrayManager) handleMenuEvents() {
	for {
		select {
		case <-t.ctx.Done():
			return
			
		case <-t.connectItem.ClickedCh:
			t.handleConnect()
			
		case <-t.disconnectItem.ClickedCh:
			t.handleDisconnect()
			
		case <-t.loginItem.ClickedCh:
			t.handleLogin()
			
		case <-t.logoutItem.ClickedCh:
			t.handleLogout()
			
		case <-t.settingsItem.ClickedCh:
			t.handleSettings()
			
		case <-t.aboutItem.ClickedCh:
			t.handleAbout()
			
		case <-t.quitItem.ClickedCh:
			t.handleQuit()
		}
	}
}

// statusUpdateLoop periodically updates the status
func (t *TrayManager) statusUpdateLoop() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-t.ctx.Done():
			return
		case <-ticker.C:
			t.updateStatus()
		}
	}
}

// updateStatus updates the tray status
func (t *TrayManager) updateStatus() {
	var status string
	var tooltip string
	
	if !t.authManager.IsAuthenticated() {
		status = "Status: Not authenticated"
		tooltip = "CloudToLocalLLM Bridge - Not authenticated"
		t.connectItem.Disable()
		t.disconnectItem.Disable()
		t.loginItem.Enable()
		t.logoutItem.Disable()
	} else if t.tunnelManager.IsConnected() {
		status = "Status: Connected"
		tooltip = "CloudToLocalLLM Bridge - Connected to cloud relay"
		t.connectItem.Disable()
		t.disconnectItem.Enable()
		t.loginItem.Disable()
		t.logoutItem.Enable()
		
		// Update icon to show connected state
		systray.SetIcon(getConnectedIconData())
	} else {
		status = "Status: Authenticated, not connected"
		tooltip = "CloudToLocalLLM Bridge - Ready to connect"
		t.connectItem.Enable()
		t.disconnectItem.Disable()
		t.loginItem.Disable()
		t.logoutItem.Enable()
		
		// Update icon to show disconnected state
		systray.SetIcon(getIconData())
	}
	
	t.statusItem.SetTitle(status)
	systray.SetTooltip(tooltip)
}

// Event handlers

func (t *TrayManager) handleConnect() {
	t.logger.Info("User requested connection")
	
	if !t.authManager.IsAuthenticated() {
		t.showNotification("Error", "Please login first")
		return
	}
	
	go func() {
		if err := t.tunnelManager.Start(t.ctx); err != nil {
			t.logger.Errorf("Failed to start tunnel: %v", err)
			t.showNotification("Connection Error", fmt.Sprintf("Failed to connect: %v", err))
		}
	}()
}

func (t *TrayManager) handleDisconnect() {
	t.logger.Info("User requested disconnection")
	t.tunnelManager.Stop()
	t.showNotification("Disconnected", "Disconnected from cloud relay")
}

func (t *TrayManager) handleLogin() {
	t.logger.Info("User requested login")
	
	go func() {
		if err := t.authManager.Login(t.ctx); err != nil {
			t.logger.Errorf("Login failed: %v", err)
			t.showNotification("Login Error", fmt.Sprintf("Login failed: %v", err))
		} else {
			t.logger.Info("Login successful")
			t.showNotification("Login Successful", "Successfully authenticated with Auth0")
		}
	}()
}

func (t *TrayManager) handleLogout() {
	t.logger.Info("User requested logout")
	
	// Stop tunnel if connected
	if t.tunnelManager.IsConnected() {
		t.tunnelManager.Stop()
	}
	
	// Clear authentication
	if err := t.authManager.Logout(); err != nil {
		t.logger.Errorf("Logout error: %v", err)
	}
	
	t.showNotification("Logged Out", "Successfully logged out")
}

func (t *TrayManager) handleSettings() {
	t.logger.Info("User requested settings")
	// TODO: Implement settings dialog or open config file
	t.showNotification("Settings", "Settings functionality coming soon")
}

func (t *TrayManager) handleAbout() {
	t.logger.Info("User requested about")
	about := `CloudToLocalLLM Desktop Bridge v1.0.0

A secure bridge connecting your local Ollama instance 
to the CloudToLocalLLM cloud service.

Features:
• Secure Auth0 authentication
• WebSocket tunnel to cloud relay
• System tray integration
• Automatic reconnection

Visit: https://cloudtolocalllm.online`
	
	t.showNotification("About CloudToLocalLLM Bridge", about)
}

func (t *TrayManager) handleQuit() {
	t.logger.Info("User requested quit")
	
	// Stop tunnel
	t.tunnelManager.Stop()
	
	// Exit application
	os.Exit(0)
}

// showNotification shows a desktop notification
func (t *TrayManager) showNotification(title, message string) {
	// Try to use notify-send on Linux
	cmd := exec.Command("notify-send", title, message)
	if err := cmd.Run(); err != nil {
		t.logger.Warnf("Failed to show notification: %v", err)
	}
}

// Icon data (embedded as base64 or byte arrays)
func getIconData() []byte {
	// This would contain the actual icon data
	// For now, return empty slice - in real implementation,
	// embed the icon file or use go:embed
	return []byte{}
}

func getConnectedIconData() []byte {
	// This would contain the connected state icon data
	// For now, return empty slice - in real implementation,
	// embed the icon file or use go:embed
	return []byte{}
}
