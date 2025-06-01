package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
	"cloudtolocalllm-bridge/config"
)

// TokenStore holds authentication tokens
type TokenStore struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token,omitempty"`
	IDToken      string    `json:"id_token,omitempty"`
	ExpiresAt    time.Time `json:"expires_at"`
	TokenType    string    `json:"token_type"`
}

// AuthManager handles Auth0 authentication
type AuthManager struct {
	config *config.Config
	logger *logrus.Logger
	tokens *TokenStore
}

// NewAuthManager creates a new authentication manager
func NewAuthManager(cfg *config.Config, logger *logrus.Logger) *AuthManager {
	return &AuthManager{
		config: cfg,
		logger: logger,
	}
}

// LoadTokens loads stored tokens from disk
func (a *AuthManager) LoadTokens() error {
	tokenPath := config.GetTokenPath()
	
	data, err := os.ReadFile(tokenPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil // No tokens stored yet
		}
		return err
	}
	
	tokens := &TokenStore{}
	if err := json.Unmarshal(data, tokens); err != nil {
		return err
	}
	
	a.tokens = tokens
	return nil
}

// SaveTokens saves tokens to disk
func (a *AuthManager) SaveTokens() error {
	if a.tokens == nil {
		return nil
	}
	
	tokenPath := config.GetTokenPath()
	
	// Create directory if it doesn't exist
	if err := os.MkdirAll(filepath.Dir(tokenPath), 0755); err != nil {
		return err
	}
	
	data, err := json.Marshal(a.tokens)
	if err != nil {
		return err
	}
	
	return os.WriteFile(tokenPath, data, 0600)
}

// IsAuthenticated checks if we have valid tokens
func (a *AuthManager) IsAuthenticated() bool {
	if a.tokens == nil {
		return false
	}
	
	// Check if token is expired (with 5 minute buffer)
	return time.Now().Add(5 * time.Minute).Before(a.tokens.ExpiresAt)
}

// GetAccessToken returns the current access token
func (a *AuthManager) GetAccessToken() string {
	if a.tokens == nil {
		return ""
	}
	return a.tokens.AccessToken
}

// Login initiates the Auth0 login flow
func (a *AuthManager) Login(ctx context.Context) error {
	// Generate PKCE parameters
	codeVerifier, err := generateCodeVerifier()
	if err != nil {
		return fmt.Errorf("failed to generate code verifier: %w", err)
	}
	
	codeChallenge := generateCodeChallenge(codeVerifier)
	state := generateState()
	
	// Build authorization URL
	authURL := a.buildAuthURL(codeChallenge, state)
	
	a.logger.Info("Opening browser for authentication...")
	
	// Open browser
	if err := openBrowser(authURL); err != nil {
		a.logger.Warnf("Failed to open browser automatically: %v", err)
		a.logger.Infof("Please open this URL manually: %s", authURL)
	}
	
	// Start local server to handle callback
	return a.handleCallback(ctx, codeVerifier, state)
}

// buildAuthURL builds the Auth0 authorization URL
func (a *AuthManager) buildAuthURL(codeChallenge, state string) string {
	params := url.Values{}
	params.Set("response_type", "code")
	params.Set("client_id", a.config.Auth0.ClientID)
	params.Set("redirect_uri", a.config.Auth0.RedirectURI)
	params.Set("scope", strings.Join(a.config.Auth0.Scopes, " "))
	params.Set("state", state)
	params.Set("code_challenge", codeChallenge)
	params.Set("code_challenge_method", "S256")
	params.Set("audience", a.config.Auth0.Audience)
	
	return fmt.Sprintf("https://%s/authorize?%s", a.config.Auth0.Domain, params.Encode())
}

// handleCallback handles the OAuth callback
func (a *AuthManager) handleCallback(ctx context.Context, codeVerifier, expectedState string) error {
	// Create a channel to receive the authorization code
	codeChan := make(chan string, 1)
	errorChan := make(chan error, 1)
	
	// Start HTTP server to handle callback
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		code := r.URL.Query().Get("code")
		state := r.URL.Query().Get("state")
		errorParam := r.URL.Query().Get("error")
		
		if errorParam != "" {
			errorDesc := r.URL.Query().Get("error_description")
			errorChan <- fmt.Errorf("auth error: %s - %s", errorParam, errorDesc)
			return
		}
		
		if state != expectedState {
			errorChan <- fmt.Errorf("invalid state parameter")
			return
		}
		
		if code == "" {
			errorChan <- fmt.Errorf("no authorization code received")
			return
		}
		
		// Send success response
		w.Header().Set("Content-Type", "text/html")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`
			<html>
				<body>
					<h1>Authentication Successful!</h1>
					<p>You can now close this window and return to the CloudToLocalLLM Bridge.</p>
					<script>window.close();</script>
				</body>
			</html>
		`))
		
		codeChan <- code
	})
	
	server := &http.Server{
		Addr:    ":3025",
		Handler: mux,
	}
	
	// Start server in goroutine
	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			errorChan <- err
		}
	}()
	
	// Wait for callback or timeout
	select {
	case code := <-codeChan:
		// Exchange code for tokens
		if err := a.exchangeCodeForTokens(code, codeVerifier); err != nil {
			return err
		}
		
		// Shutdown server
		server.Shutdown(context.Background())
		return nil
		
	case err := <-errorChan:
		server.Shutdown(context.Background())
		return err
		
	case <-ctx.Done():
		server.Shutdown(context.Background())
		return ctx.Err()
		
	case <-time.After(5 * time.Minute):
		server.Shutdown(context.Background())
		return fmt.Errorf("authentication timeout")
	}
}

// exchangeCodeForTokens exchanges authorization code for access tokens
func (a *AuthManager) exchangeCodeForTokens(code, codeVerifier string) error {
	tokenURL := fmt.Sprintf("https://%s/oauth/token", a.config.Auth0.Domain)
	
	data := url.Values{}
	data.Set("grant_type", "authorization_code")
	data.Set("client_id", a.config.Auth0.ClientID)
	data.Set("code", code)
	data.Set("redirect_uri", a.config.Auth0.RedirectURI)
	data.Set("code_verifier", codeVerifier)
	
	resp, err := http.PostForm(tokenURL, data)
	if err != nil {
		return fmt.Errorf("failed to exchange code for tokens: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("token exchange failed with status: %d", resp.StatusCode)
	}
	
	var tokenResponse struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		IDToken      string `json:"id_token"`
		TokenType    string `json:"token_type"`
		ExpiresIn    int    `json:"expires_in"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&tokenResponse); err != nil {
		return fmt.Errorf("failed to decode token response: %w", err)
	}
	
	// Store tokens
	a.tokens = &TokenStore{
		AccessToken:  tokenResponse.AccessToken,
		RefreshToken: tokenResponse.RefreshToken,
		IDToken:      tokenResponse.IDToken,
		TokenType:    tokenResponse.TokenType,
		ExpiresAt:    time.Now().Add(time.Duration(tokenResponse.ExpiresIn) * time.Second),
	}
	
	return a.SaveTokens()
}

// Logout clears stored tokens
func (a *AuthManager) Logout() error {
	a.tokens = nil
	tokenPath := config.GetTokenPath()
	if err := os.Remove(tokenPath); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

// Helper functions

func generateCodeVerifier() (string, error) {
	data := make([]byte, 32)
	if _, err := rand.Read(data); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(data), nil
}

func generateCodeChallenge(verifier string) string {
	hash := sha256.Sum256([]byte(verifier))
	return base64.RawURLEncoding.EncodeToString(hash[:])
}

func generateState() string {
	data := make([]byte, 16)
	rand.Read(data)
	return base64.RawURLEncoding.EncodeToString(data)
}

func openBrowser(url string) error {
	var cmd *exec.Cmd
	
	// Try different commands based on the system
	commands := [][]string{
		{"xdg-open", url},     // Linux
		{"open", url},         // macOS
		{"cmd", "/c", "start", url}, // Windows
	}
	
	for _, cmdArgs := range commands {
		cmd = exec.Command(cmdArgs[0], cmdArgs[1:]...)
		if err := cmd.Start(); err == nil {
			return nil
		}
	}
	
	return fmt.Errorf("unable to open browser")
}
