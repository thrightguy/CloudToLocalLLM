#!/bin/bash
# Configure MCP Flutter Inspector for different AI clients
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              MCP Flutter Inspector Client Setup              ║${NC}"
echo -e "${BLUE}║                Configure for Your AI Tool                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect operating system
OS="unknown"
case "$(uname -s)" in
    Linux*)     OS="linux";;
    Darwin*)    OS="macos";;
    CYGWIN*|MINGW*|MSYS*) OS="windows";;
esac

echo -e "${CYAN}🔍 Detected OS: ${OS}${NC}"
echo ""

echo -e "${BLUE}📋 Select your AI tool:${NC}"
echo -e "${YELLOW}1. Cursor${NC}"
echo -e "${YELLOW}2. Claude Desktop${NC}"
echo -e "${YELLOW}3. Cline AI (VSCode)${NC}"
echo -e "${YELLOW}4. Augment (VSCode)${NC}"
echo -e "${YELLOW}5. Custom setup${NC}"
echo ""

read -p "Choose an option (1-5): " -n 1 -r
echo ""

# Set configuration paths based on OS and tool
case $REPLY in
    1)
        echo -e "${CYAN}🎯 Configuring for Cursor...${NC}"
        CLIENT="cursor"
        case $OS in
            "macos")
                CONFIG_PATH="$HOME/.cursor/mcp.json"
                ;;
            "linux")
                CONFIG_PATH="$HOME/.config/cursor/mcp.json"
                ;;
            "windows")
                CONFIG_PATH="$APPDATA/cursor/mcp.json"
                ;;
        esac
        SOURCE_CONFIG="config/cursor_mcp.json"
        ;;
    2)
        echo -e "${CYAN}🎯 Configuring for Claude Desktop...${NC}"
        CLIENT="claude"
        case $OS in
            "macos")
                CONFIG_PATH="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
                ;;
            "linux")
                CONFIG_PATH="$HOME/.config/claude/claude_desktop_config.json"
                ;;
            "windows")
                CONFIG_PATH="$APPDATA/Claude/claude_desktop_config.json"
                ;;
        esac
        SOURCE_CONFIG="config/claude_desktop_mcp.json"
        ;;
    3)
        echo -e "${CYAN}🎯 Configuring for Cline AI...${NC}"
        CLIENT="cline"
        case $OS in
            "macos")
                CONFIG_PATH="$HOME/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
                ;;
            "linux")
                CONFIG_PATH="$HOME/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
                ;;
            "windows")
                CONFIG_PATH="$APPDATA/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
                ;;
        esac
        SOURCE_CONFIG="config/cline_mcp.json"
        ;;
    4)
        echo -e "${CYAN}🎯 Configuring for Augment (VSCode)...${NC}"
        CLIENT="augment"
        echo -e "${YELLOW}For Augment, you'll need to manually configure the MCP server.${NC}"
        echo -e "${YELLOW}Use the configuration from: config/mcp_servers.json${NC}"
        SOURCE_CONFIG="config/mcp_servers.json"
        CONFIG_PATH=""
        ;;
    5)
        echo -e "${CYAN}🎯 Custom setup...${NC}"
        CLIENT="custom"
        echo -e "${YELLOW}Please specify the configuration file path:${NC}"
        read -p "Config Path: " CONFIG_PATH
        SOURCE_CONFIG="config/mcp_servers.json"
        ;;
    *)
        echo -e "${RED}Invalid option. Exiting.${NC}"
        exit 1
        ;;
esac

# Check if source config exists
if [ ! -f "$SOURCE_CONFIG" ]; then
    echo -e "${RED}❌ Source configuration not found: $SOURCE_CONFIG${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Source configuration found${NC}"

# For Augment, just show the config
if [ "$CLIENT" = "augment" ]; then
    echo ""
    echo -e "${BLUE}📋 Augment Configuration:${NC}"
    echo -e "${YELLOW}Copy the following configuration to your Augment settings:${NC}"
    echo ""
    cat "$SOURCE_CONFIG"
    echo ""
    echo -e "${BLUE}📖 Instructions:${NC}"
    echo -e "${YELLOW}1. Open VSCode with Augment extension${NC}"
    echo -e "${YELLOW}2. Configure MCP servers using the above configuration${NC}"
    echo -e "${YELLOW}3. Enable 'flutter-inspector-remote' when using remote debugging${NC}"
    exit 0
fi

# Create config directory if it doesn't exist
if [ -n "$CONFIG_PATH" ]; then
    CONFIG_DIR=$(dirname "$CONFIG_PATH")
    if [ ! -d "$CONFIG_DIR" ]; then
        echo -e "${YELLOW}📁 Creating configuration directory: $CONFIG_DIR${NC}"
        mkdir -p "$CONFIG_DIR"
    fi

    # Backup existing config if it exists
    if [ -f "$CONFIG_PATH" ]; then
        BACKUP_PATH="${CONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}💾 Backing up existing config to: $BACKUP_PATH${NC}"
        cp "$CONFIG_PATH" "$BACKUP_PATH"
    fi

    # Copy configuration
    echo -e "${YELLOW}📝 Installing MCP configuration...${NC}"
    cp "$SOURCE_CONFIG" "$CONFIG_PATH"

    echo -e "${GREEN}✅ Configuration installed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📍 Configuration location: ${CONFIG_PATH}${NC}"
else
    echo -e "${YELLOW}⚠️  Please manually copy the configuration from: $SOURCE_CONFIG${NC}"
fi

echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo -e "${YELLOW}1. Restart your AI tool (${CLIENT})${NC}"
echo -e "${YELLOW}2. For local debugging:${NC}"
echo -e "${CYAN}   • Run your Flutter app with: ./flutter/bin/flutter run --debug --host-vmservice-port=8182 --dds-port=8181 --enable-vm-service --disable-service-auth-codes${NC}"
echo -e "${YELLOW}3. For remote debugging:${NC}"
echo -e "${CYAN}   • Run: ./scripts/setup_mcp_tunnel.sh${NC}"
echo -e "${CYAN}   • Enable the remote server in your config${NC}"
echo -e "${YELLOW}4. Test with commands like:${NC}"
echo -e "${CYAN}   • 'Take a screenshot of the Flutter app'${NC}"
echo -e "${CYAN}   • 'Show me the widget tree'${NC}"

echo ""
echo -e "${BLUE}📚 For more information:${NC}"
echo -e "${CYAN}docs/MCP_REMOTE_DEBUGGING_GUIDE.md${NC}"

# Special notes for different clients
case $CLIENT in
    "cursor")
        echo ""
        echo -e "${RED}⚠️  Cursor Note: Resources are disabled (RESOURCES_SUPPORTED=false)${NC}"
        echo -e "${YELLOW}This is required for Cursor compatibility.${NC}"
        ;;
    "claude")
        echo ""
        echo -e "${GREEN}💡 Claude Desktop supports full MCP features including resources.${NC}"
        ;;
    "cline")
        echo ""
        echo -e "${GREEN}💡 Cline AI supports full MCP features with auto-approval options.${NC}"
        ;;
esac
