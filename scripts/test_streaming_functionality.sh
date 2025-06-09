#!/bin/bash

# CloudToLocalLLM v3.4.1 Streaming Functionality Test Script
# Tests the new streaming tunnel functionality with local Ollama

set -e

echo "🚀 CloudToLocalLLM v3.4.1 Streaming Functionality Test"
echo "======================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
OLLAMA_HOST="localhost"
OLLAMA_PORT="11434"
OLLAMA_URL="http://${OLLAMA_HOST}:${OLLAMA_PORT}"

echo -e "${BLUE}📋 Test Configuration:${NC}"
echo "  Ollama URL: $OLLAMA_URL"
echo "  Test Model: llama2 (if available)"
echo ""

# Function to check if Ollama is running
check_ollama() {
    echo -e "${BLUE}🔍 Checking Ollama availability...${NC}"
    
    if curl -s "$OLLAMA_URL/api/version" > /dev/null 2>&1; then
        local version=$(curl -s "$OLLAMA_URL/api/version" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        echo -e "${GREEN}✅ Ollama is running (version: $version)${NC}"
        return 0
    else
        echo -e "${RED}❌ Ollama is not running or not accessible at $OLLAMA_URL${NC}"
        echo -e "${YELLOW}💡 Please start Ollama with: ollama serve${NC}"
        return 1
    fi
}

# Function to check available models
check_models() {
    echo -e "${BLUE}🔍 Checking available models...${NC}"
    
    local models=$(curl -s "$OLLAMA_URL/api/tags" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | head -5)
    
    if [ -n "$models" ]; then
        echo -e "${GREEN}✅ Available models:${NC}"
        echo "$models" | while read -r model; do
            echo "  - $model"
        done
        return 0
    else
        echo -e "${YELLOW}⚠️  No models found. You may need to pull a model first.${NC}"
        echo -e "${YELLOW}💡 Try: ollama pull llama2${NC}"
        return 1
    fi
}

# Function to test basic HTTP connection
test_http_connection() {
    echo -e "${BLUE}🔗 Testing basic HTTP connection...${NC}"
    
    local response=$(curl -s -w "%{http_code}" "$OLLAMA_URL/api/version" -o /tmp/ollama_version.json)
    
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✅ HTTP connection successful${NC}"
        return 0
    else
        echo -e "${RED}❌ HTTP connection failed (status: $response)${NC}"
        return 1
    fi
}

# Function to test streaming endpoint
test_streaming_endpoint() {
    echo -e "${BLUE}🌊 Testing streaming endpoint...${NC}"
    
    # Get first available model
    local model=$(curl -s "$OLLAMA_URL/api/tags" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | head -1)
    
    if [ -z "$model" ]; then
        echo -e "${YELLOW}⚠️  No models available for streaming test${NC}"
        return 1
    fi
    
    echo "  Using model: $model"
    
    # Test streaming chat endpoint with a simple prompt
    local test_prompt="Hello, this is a test. Please respond with just 'Hello back!'"
    local request_body=$(cat <<EOF
{
    "model": "$model",
    "messages": [
        {"role": "user", "content": "$test_prompt"}
    ],
    "stream": true
}
EOF
)
    
    echo "  Sending streaming request..."
    
    # Send streaming request and capture first few chunks
    local response=$(curl -s -X POST "$OLLAMA_URL/api/chat" \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        --max-time 30 | head -5)
    
    if [ -n "$response" ]; then
        echo -e "${GREEN}✅ Streaming endpoint responding${NC}"
        echo "  Sample response chunks:"
        echo "$response" | while read -r line; do
            if [ -n "$line" ]; then
                echo "    $line"
            fi
        done
        return 0
    else
        echo -e "${RED}❌ Streaming endpoint not responding${NC}"
        return 1
    fi
}

# Function to run Flutter tests
test_flutter_implementation() {
    echo -e "${BLUE}🧪 Running Flutter streaming tests...${NC}"
    
    if flutter test test/streaming_integration_test.dart --reporter=compact; then
        echo -e "${GREEN}✅ Flutter streaming tests passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Flutter streaming tests failed${NC}"
        return 1
    fi
}

# Function to test application build
test_application_build() {
    echo -e "${BLUE}🔨 Testing application build...${NC}"
    
    if flutter build linux --debug > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Application builds successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Application build failed${NC}"
        return 1
    fi
}

# Main test execution
main() {
    local tests_passed=0
    local tests_total=5
    
    echo -e "${BLUE}🏁 Starting streaming functionality tests...${NC}"
    echo ""
    
    # Test 1: Check Ollama availability
    if check_ollama; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 2: Check available models
    if check_models; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 3: Test HTTP connection
    if test_http_connection; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 4: Test streaming endpoint
    if test_streaming_endpoint; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 5: Test Flutter implementation
    if test_flutter_implementation; then
        ((tests_passed++))
    fi
    echo ""
    
    # Summary
    echo "======================================================"
    echo -e "${BLUE}📊 Test Results Summary:${NC}"
    echo "  Tests passed: $tests_passed/$tests_total"
    
    if [ $tests_passed -eq $tests_total ]; then
        echo -e "${GREEN}🎉 All streaming functionality tests passed!${NC}"
        echo -e "${GREEN}✅ CloudToLocalLLM v3.4.1 streaming is ready for use${NC}"
        exit 0
    elif [ $tests_passed -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Some tests passed, but issues were found${NC}"
        echo -e "${YELLOW}💡 Check the failed tests above for details${NC}"
        exit 1
    else
        echo -e "${RED}❌ All tests failed${NC}"
        echo -e "${RED}🔧 Please check your Ollama installation and configuration${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
