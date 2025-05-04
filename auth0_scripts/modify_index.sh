#!/bin/bash

# Source common functions
source /tmp/auth0_scripts/common.sh

yellow "Modifying index.html for Auth0 integration..."

# Add Auth0 callback handler to index.html
INDEX_FILE="$WEB_ROOT/index.html"
if [ -f "$INDEX_FILE" ]; then
    # Create backup of index.html if not already done
    if [ ! -f "$BACKUP_DIR/index.html.original" ]; then
        cp "$INDEX_FILE" "$BACKUP_DIR/index.html.original"
    fi
    
    # Create Auth0 callback script content
    cat > /tmp/auth0_callback.js << 'EOF'
<!-- Auth0 callback handler -->
<script>
  // Handle Auth0 callback redirect
  (function() {
    const urlParams = new URLSearchParams(window.location.search);
    const code = urlParams.get("code");
    const state = urlParams.get("state");
    
    if (code && state) {
      console.log("Auth0 callback detected, storing auth code");
      sessionStorage.setItem("auth0_code", code);
      sessionStorage.setItem("auth0_state", state);
      
      if (window.history && window.history.replaceState) {
        window.history.replaceState({}, document.title, "/");
      }
    }
  })();
</script>
EOF

    # Try various methods to insert the script before </head>
    # Method 1: Find the line number and split the file
    HEAD_LINE=$(grep -n "</head>" "$INDEX_FILE" | cut -d':' -f1 | head -n 1)
    if [ -n "$HEAD_LINE" ]; then
        yellow "Inserting Auth0 callback script at line $HEAD_LINE..."
        head -n $((HEAD_LINE-1)) "$INDEX_FILE" > /tmp/index.head
        cat /tmp/auth0_callback.js >> /tmp/index.head
        tail -n +$HEAD_LINE "$INDEX_FILE" >> /tmp/index.head
        
        # Replace original file
        mv /tmp/index.head "$INDEX_FILE"
        green "Added Auth0 callback handler to index.html"
    else
        # Method 2: Try sed as a fallback
        yellow "Line number method failed, trying sed method..."
        # Create a safe script with no special characters
        SAFE_SCRIPT=$(cat /tmp/auth0_callback.js | tr '\n' 'β' | sed 's/β/\\n/g')
        
        # Use awk for safer insertion
        awk '{print} /<\/head>/{print "<!-- Auth0 callback handler -->\n<script>\n  // Handle Auth0 callback redirect\n  (function() {\n    const urlParams = new URLSearchParams(window.location.search);\n    const code = urlParams.get(\"code\");\n    const state = urlParams.get(\"state\");\n    \n    if (code && state) {\n      console.log(\"Auth0 callback detected, storing auth code\");\n      sessionStorage.setItem(\"auth0_code\", code);\n      sessionStorage.setItem(\"auth0_state\", state);\n      \n      if (window.history && window.history.replaceState) {\n        window.history.replaceState({}, document.title, \"/\");\n      }\n    }\n  })();\n</script>"}' "$INDEX_FILE" > /tmp/index.new
        
        if [ -s "/tmp/index.new" ]; then
            mv /tmp/index.new "$INDEX_FILE"
            green "Added Auth0 callback handler to index.html using awk method"
        else
            red "Failed to modify index.html"
        fi
    fi
else
    red "Warning: index.html not found at $INDEX_FILE"
fi