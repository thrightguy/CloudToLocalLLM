#!/bin/bash
# CloudToLocalLLM Tunnel Verification Test Runner
# Runs Playwright tests to verify tunnel usage and prevent localhost calls

set -e

# Default values
DEPLOYMENT_URL="https://app.cloudtolocalllm.online"
HEADLESS=false
DEBUG=false
BROWSER="chromium"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            DEPLOYMENT_URL="$2"
            shift 2
            ;;
        --headless)
            HEADLESS=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --browser)
            BROWSER="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --url URL        Deployment URL to test (default: https://app.cloudtolocalllm.online)"
            echo "  --headless       Run in headless mode"
            echo "  --debug          Enable debug mode"
            echo "  --browser NAME   Browser to use (default: chromium)"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "🧪 CloudToLocalLLM Tunnel Verification Test"
echo "============================================"

# Set environment variables
export DEPLOYMENT_URL="$DEPLOYMENT_URL"
export PWDEBUG=$([ "$DEBUG" = true ] && echo "1" || echo "0")

echo "🌐 Testing deployment: $DEPLOYMENT_URL"
echo "🖥️  Browser: $BROWSER"
echo "👁️  Headless: $HEADLESS"
echo "🐛 Debug mode: $DEBUG"

# Check if npx is available
if ! command -v npx &> /dev/null; then
    echo "❌ Error: npx not found. Please install Node.js"
    exit 1
fi

# Install Playwright if needed
echo "📦 Checking Playwright installation..."
if ! npx playwright --version &> /dev/null; then
    echo "📦 Installing Playwright..."
    npx playwright install
fi

# Create test results directory
mkdir -p test-results/tunnel-verification

# Build the command
PLAYWRIGHT_ARGS=(
    "playwright" "test"
    "tests/e2e/tunnel-verification.spec.js"
    "--project=${BROWSER}-auth-analysis"
    "--reporter=list,html,json"
)

if [ "$HEADLESS" = true ]; then
    PLAYWRIGHT_ARGS+=("--headed=false")
else
    PLAYWRIGHT_ARGS+=("--headed=true")
fi

if [ "$DEBUG" = true ]; then
    PLAYWRIGHT_ARGS+=("--debug")
fi

echo "🚀 Starting tunnel verification tests..."
echo "Command: npx ${PLAYWRIGHT_ARGS[*]}"

# Run the test
if npx "${PLAYWRIGHT_ARGS[@]}"; then
    EXIT_CODE=0
else
    EXIT_CODE=$?
fi

echo ""
echo "📊 Test Results:"
echo "==============="

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All tunnel verification tests passed!"
    echo "🛡️  No localhost calls detected"
    echo "🌐 Cloud proxy tunnel working correctly"
else
    echo "❌ Some tests failed!"
    echo "🚨 Check the output above for localhost calls"
    echo "🔍 Review the HTML report for detailed analysis"
fi

# Show report locations
echo ""
echo "📋 Test Reports:"
echo "==============="
echo "📄 HTML Report: test-results/html-report/index.html"
echo "📊 JSON Report: test-results/test-results.json"
echo "🌐 Network HAR: test-results/network.har"

if [ -f "test-results/html-report/index.html" ]; then
    echo ""
    echo "🌐 HTML report available at: test-results/html-report/index.html"
    
    # Try to open the report on macOS or Linux
    if command -v open &> /dev/null; then
        echo "🌐 Opening HTML report..."
        open test-results/html-report/index.html
    elif command -v xdg-open &> /dev/null; then
        echo "🌐 Opening HTML report..."
        xdg-open test-results/html-report/index.html
    fi
fi

exit $EXIT_CODE
