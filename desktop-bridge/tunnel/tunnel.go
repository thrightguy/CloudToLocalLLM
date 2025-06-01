package tunnel

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/sirupsen/logrus"
	"cloudtolocalllm-bridge/auth"
	"cloudtolocalllm-bridge/config"
)

// TunnelManager manages the WebSocket tunnel to the cloud relay
type TunnelManager struct {
	config      *config.Config
	logger      *logrus.Logger
	authManager *auth.AuthManager
	
	conn        *websocket.Conn
	connMutex   sync.RWMutex
	isConnected bool
	
	// Channels for communication
	stopChan    chan struct{}
	reconnectChan chan struct{}
	
	// HTTP client for Ollama requests
	ollamaClient *http.Client
}

// Message represents a tunnel message
type Message struct {
	Type      string            `json:"type"`
	ID        string            `json:"id"`
	Method    string            `json:"method,omitempty"`
	Path      string            `json:"path,omitempty"`
	Headers   map[string]string `json:"headers,omitempty"`
	Body      []byte            `json:"body,omitempty"`
	Status    int               `json:"status,omitempty"`
	Error     string            `json:"error,omitempty"`
	Timestamp time.Time         `json:"timestamp"`
}

// NewTunnelManager creates a new tunnel manager
func NewTunnelManager(cfg *config.Config, logger *logrus.Logger, authMgr *auth.AuthManager) *TunnelManager {
	return &TunnelManager{
		config:      cfg,
		logger:      logger,
		authManager: authMgr,
		stopChan:    make(chan struct{}),
		reconnectChan: make(chan struct{}, 1),
		ollamaClient: &http.Client{
			Timeout: time.Duration(cfg.Ollama.Timeout) * time.Second,
		},
	}
}

// Start starts the tunnel connection
func (t *TunnelManager) Start(ctx context.Context) error {
	t.logger.Info("Starting tunnel manager...")
	
	// Start connection loop
	go t.connectionLoop(ctx)
	
	// Start reconnection handler
	go t.reconnectionHandler(ctx)
	
	return nil
}

// Stop stops the tunnel connection
func (t *TunnelManager) Stop() {
	t.logger.Info("Stopping tunnel manager...")
	close(t.stopChan)
	
	t.connMutex.Lock()
	if t.conn != nil {
		t.conn.Close()
		t.conn = nil
	}
	t.isConnected = false
	t.connMutex.Unlock()
}

// IsConnected returns the connection status
func (t *TunnelManager) IsConnected() bool {
	t.connMutex.RLock()
	defer t.connMutex.RUnlock()
	return t.isConnected
}

// connectionLoop manages the WebSocket connection
func (t *TunnelManager) connectionLoop(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.stopChan:
			return
		default:
			if err := t.connect(ctx); err != nil {
				t.logger.Errorf("Failed to connect: %v", err)
				
				// Trigger reconnection after delay
				select {
				case <-time.After(5 * time.Second):
					select {
					case t.reconnectChan <- struct{}{}:
					default:
					}
				case <-ctx.Done():
					return
				case <-t.stopChan:
					return
				}
			}
		}
	}
}

// reconnectionHandler handles reconnection attempts
func (t *TunnelManager) reconnectionHandler(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.stopChan:
			return
		case <-t.reconnectChan:
			// Wait a bit before reconnecting
			time.Sleep(2 * time.Second)
		}
	}
}

// connect establishes the WebSocket connection
func (t *TunnelManager) connect(ctx context.Context) error {
	if !t.authManager.IsAuthenticated() {
		return fmt.Errorf("not authenticated")
	}
	
	// Parse WebSocket URL
	wsURL, err := url.Parse(t.config.Cloud.WebSocketURL)
	if err != nil {
		return fmt.Errorf("invalid WebSocket URL: %w", err)
	}
	
	// Set up headers with authentication
	headers := http.Header{}
	headers.Set("Authorization", "Bearer "+t.authManager.GetAccessToken())
	headers.Set("User-Agent", "CloudToLocalLLM-Bridge/1.0")
	
	t.logger.Infof("Connecting to %s", wsURL.String())
	
	// Establish WebSocket connection
	conn, _, err := websocket.DefaultDialer.DialContext(ctx, wsURL.String(), headers)
	if err != nil {
		return fmt.Errorf("failed to dial WebSocket: %w", err)
	}
	
	t.connMutex.Lock()
	t.conn = conn
	t.isConnected = true
	t.connMutex.Unlock()
	
	t.logger.Info("WebSocket connection established")
	
	// Register bridge with cloud service
	if err := t.registerBridge(); err != nil {
		t.logger.Warnf("Failed to register bridge: %v", err)
	}
	
	// Start message handling
	go t.handleMessages(ctx)
	
	// Wait for connection to close
	<-ctx.Done()
	return ctx.Err()
}

// registerBridge registers this bridge instance with the cloud service
func (t *TunnelManager) registerBridge() error {
	registerData := map[string]interface{}{
		"bridge_id": "desktop-bridge",
		"version":   "1.0.0",
		"platform":  "linux",
		"timestamp": time.Now(),
	}
	
	jsonData, err := json.Marshal(registerData)
	if err != nil {
		return err
	}
	
	req, err := http.NewRequest("POST", t.config.Cloud.RegisterURL, bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}
	
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+t.authManager.GetAccessToken())
	
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("registration failed with status: %d", resp.StatusCode)
	}
	
	t.logger.Info("Bridge registered successfully")
	return nil
}

// handleMessages handles incoming WebSocket messages
func (t *TunnelManager) handleMessages(ctx context.Context) {
	defer func() {
		t.connMutex.Lock()
		if t.conn != nil {
			t.conn.Close()
			t.conn = nil
		}
		t.isConnected = false
		t.connMutex.Unlock()
		
		// Trigger reconnection
		select {
		case t.reconnectChan <- struct{}{}:
		default:
		}
	}()
	
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.stopChan:
			return
		default:
			t.connMutex.RLock()
			conn := t.conn
			t.connMutex.RUnlock()
			
			if conn == nil {
				return
			}
			
			// Read message
			_, messageData, err := conn.ReadMessage()
			if err != nil {
				t.logger.Errorf("Failed to read WebSocket message: %v", err)
				return
			}
			
			// Parse message
			var msg Message
			if err := json.Unmarshal(messageData, &msg); err != nil {
				t.logger.Errorf("Failed to parse message: %v", err)
				continue
			}
			
			// Handle message
			go t.handleMessage(ctx, &msg)
		}
	}
}

// handleMessage processes a single message
func (t *TunnelManager) handleMessage(ctx context.Context, msg *Message) {
	switch msg.Type {
	case "request":
		t.handleOllamaRequest(ctx, msg)
	case "ping":
		t.sendPong(msg.ID)
	default:
		t.logger.Warnf("Unknown message type: %s", msg.Type)
	}
}

// handleOllamaRequest forwards a request to local Ollama and sends response back
func (t *TunnelManager) handleOllamaRequest(ctx context.Context, msg *Message) {
	// Build Ollama URL
	ollamaURL := fmt.Sprintf("http://%s:%d%s", 
		t.config.Ollama.Host, 
		t.config.Ollama.Port, 
		msg.Path)
	
	// Create request
	var body io.Reader
	if len(msg.Body) > 0 {
		body = bytes.NewReader(msg.Body)
	}
	
	req, err := http.NewRequestWithContext(ctx, msg.Method, ollamaURL, body)
	if err != nil {
		t.sendErrorResponse(msg.ID, fmt.Sprintf("Failed to create request: %v", err))
		return
	}
	
	// Set headers
	for key, value := range msg.Headers {
		req.Header.Set(key, value)
	}
	
	// Make request to Ollama
	resp, err := t.ollamaClient.Do(req)
	if err != nil {
		t.sendErrorResponse(msg.ID, fmt.Sprintf("Ollama request failed: %v", err))
		return
	}
	defer resp.Body.Close()
	
	// Read response body
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		t.sendErrorResponse(msg.ID, fmt.Sprintf("Failed to read response: %v", err))
		return
	}
	
	// Send response back through tunnel
	response := &Message{
		Type:      "response",
		ID:        msg.ID,
		Status:    resp.StatusCode,
		Headers:   make(map[string]string),
		Body:      respBody,
		Timestamp: time.Now(),
	}
	
	// Copy response headers
	for key, values := range resp.Header {
		if len(values) > 0 {
			response.Headers[key] = values[0]
		}
	}
	
	t.sendMessage(response)
}

// sendPong sends a pong response
func (t *TunnelManager) sendPong(id string) {
	pong := &Message{
		Type:      "pong",
		ID:        id,
		Timestamp: time.Now(),
	}
	t.sendMessage(pong)
}

// sendErrorResponse sends an error response
func (t *TunnelManager) sendErrorResponse(id, errorMsg string) {
	response := &Message{
		Type:      "response",
		ID:        id,
		Status:    500,
		Error:     errorMsg,
		Timestamp: time.Now(),
	}
	t.sendMessage(response)
}

// sendMessage sends a message through the WebSocket
func (t *TunnelManager) sendMessage(msg *Message) {
	t.connMutex.RLock()
	conn := t.conn
	t.connMutex.RUnlock()
	
	if conn == nil {
		t.logger.Error("Cannot send message: no connection")
		return
	}
	
	data, err := json.Marshal(msg)
	if err != nil {
		t.logger.Errorf("Failed to marshal message: %v", err)
		return
	}
	
	if err := conn.WriteMessage(websocket.TextMessage, data); err != nil {
		t.logger.Errorf("Failed to send message: %v", err)
	}
}
