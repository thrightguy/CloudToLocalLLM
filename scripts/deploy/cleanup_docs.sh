#!/bin/bash
# scripts/deploy/cleanup_docs.sh
# Removes obsolete deployment documentation

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Change to project root
cd "$PROJECT_ROOT"

echo -e "${BLUE}🧹 CloudToLocalLLM Documentation Cleanup${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# List of obsolete documents to remove
OBSOLETE_DOCS=(
    "docs/DEPLOYMENT.md"
    "docs/DEPLOYMENT_CHECKLIST_ENHANCED.md"
    "docs/DEPLOYMENT_INSTRUCTIONS.md"
    "docs/DEPLOYMENT_SUMMARY.md"
    "docs/VPS_DEPLOYMENT.MD"
    "docs/VPS_DEPLOYMENT_INSTRUCTIONS.md"
    "docs/DEPLOYMENT_RESULTS.md"
    "docs/RELEASE_INSTRUCTIONS.md"
    "docs/RELEASE_UPDATE_INSTRUCTIONS.md"
)

# Create archive directory for obsolete docs
ARCHIVE_DIR="docs/archive/obsolete-$(date +%Y%m%d)"
mkdir -p "$ARCHIVE_DIR"

echo -e "${YELLOW}📦 Archiving obsolete deployment documentation...${NC}"

# Move obsolete documents to archive
for doc in "${OBSOLETE_DOCS[@]}"; do
    if [[ -f "$doc" ]]; then
        echo -e "${BLUE}📄 Archiving: $doc${NC}"
        mv "$doc" "$ARCHIVE_DIR/"
    else
        echo -e "${YELLOW}⚠️  Not found: $doc${NC}"
    fi
done

# Create README in archive
cat > "$ARCHIVE_DIR/README.md" << 'EOF'
# Obsolete Deployment Documentation Archive

This directory contains deployment documentation that has been superseded by the unified deployment workflow.

## Replacement Document

All deployment procedures are now consolidated in:
**`docs/COMPLETE_DEPLOYMENT_WORKFLOW.md`**

## Archived Documents

These documents are kept for historical reference but should NOT be used:

- `DEPLOYMENT.md` - Generic, outdated deployment guide
- `DEPLOYMENT_CHECKLIST_ENHANCED.md` - Too complex, outdated checklist
- `DEPLOYMENT_INSTRUCTIONS.md` - Incomplete deployment instructions
- `DEPLOYMENT_SUMMARY.md` - Partial deployment information
- `VPS_DEPLOYMENT.md` - VPS-only deployment guide (incomplete)
- `VPS_DEPLOYMENT_INSTRUCTIONS.md` - Outdated VPS instructions
- `DEPLOYMENT_RESULTS.md` - Historical deployment results
- `RELEASE_INSTRUCTIONS.md` - Outdated release process
- `RELEASE_UPDATE_INSTRUCTIONS.md` - Superseded update instructions

## Migration

If you were following any of these documents, please switch to:
`docs/COMPLETE_DEPLOYMENT_WORKFLOW.md`

This unified document provides:
- Complete version management
- Full deployment workflow
- Comprehensive verification
- Clear completion criteria
- Automation scripts

Archive created: $(date)
EOF

echo -e "${GREEN}✅ Obsolete documents archived to: $ARCHIVE_DIR${NC}"
echo ""

# Update main README if it exists
if [[ -f "README.md" ]]; then
    echo -e "${BLUE}📝 Updating README.md references...${NC}"
    
    # Create backup
    cp README.md README.md.backup
    
    # Replace deployment documentation references
    sed -i 's|docs/DEPLOYMENT\.md|docs/COMPLETE_DEPLOYMENT_WORKFLOW.md|g' README.md
    sed -i 's|docs/DEPLOYMENT_INSTRUCTIONS\.md|docs/COMPLETE_DEPLOYMENT_WORKFLOW.md|g' README.md
    sed -i 's|docs/VPS_DEPLOYMENT\.md|docs/COMPLETE_DEPLOYMENT_WORKFLOW.md|g' README.md
    
    echo -e "${GREEN}✅ Updated README.md references${NC}"
fi

# Create summary of active documentation
echo -e "${BLUE}📋 Active Deployment Documentation:${NC}"
echo ""
echo -e "${GREEN}✅ PRIMARY DEPLOYMENT GUIDE:${NC}"
echo "   docs/COMPLETE_DEPLOYMENT_WORKFLOW.md"
echo ""
echo -e "${GREEN}✅ SUPPORTING DOCUMENTS:${NC}"
echo "   docs/VERSIONING_STRATEGY.md - Version format reference"
echo "   scripts/version_manager.sh - Version management tool"
echo "   scripts/deploy/sync_versions.sh - Version synchronization"
echo "   scripts/deploy/verify_deployment.sh - Deployment verification"
echo "   scripts/deploy/complete_deployment.sh - Automated deployment"
echo ""
echo -e "${RED}❌ OBSOLETE (ARCHIVED):${NC}"
for doc in "${OBSOLETE_DOCS[@]}"; do
    echo "   $doc"
done

echo ""
echo -e "${YELLOW}💡 Remember:${NC}"
echo "   - Use ONLY docs/COMPLETE_DEPLOYMENT_WORKFLOW.md for deployments"
echo "   - All other deployment docs are obsolete and archived"
echo "   - Run ./scripts/deploy/verify_deployment.sh to check deployment status"

echo ""
echo -e "${GREEN}🎉 Documentation cleanup completed!${NC}"
