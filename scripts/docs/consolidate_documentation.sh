#!/bin/bash
# scripts/docs/consolidate_documentation.sh
# Consolidates CloudToLocalLLM documentation structure

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

echo -e "${BLUE}📚 CloudToLocalLLM Documentation Consolidation${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Create new directory structure
echo -e "${BLUE}📁 Creating new documentation structure...${NC}"

mkdir -p docs/DEPLOYMENT
mkdir -p docs/ARCHITECTURE
mkdir -p docs/INSTALLATION
mkdir -p docs/USER_DOCUMENTATION
mkdir -p docs/OPERATIONS
mkdir -p docs/RELEASE
mkdir -p docs/LEGAL
mkdir -p docs/archive/obsolete-$(date +%Y%m%d)

echo -e "${GREEN}✅ Directory structure created${NC}"

# Move existing documents to appropriate locations
echo -e "${BLUE}📋 Organizing existing documents...${NC}"

# Deployment documents (already in place)
echo -e "${YELLOW}📋 Deployment documents already organized${NC}"

# Legal documents
if [[ -f "docs/PRIVACY.md" ]]; then
    mv docs/PRIVACY.md docs/LEGAL/
    echo -e "${GREEN}✅ Moved PRIVACY.md to LEGAL/${NC}"
fi

if [[ -f "docs/TERMS.md" ]]; then
    mv docs/TERMS.md docs/LEGAL/
    echo -e "${GREEN}✅ Moved TERMS.md to LEGAL/${NC}"
fi

# Archive obsolete documents
OBSOLETE_DOCS=(
    "VPS_DEPLOYMENT.md"
    "CLOUD_UPDATE_SUMMARY.md"
    "TECHNICAL_SUMMARY_AUR_DEPLOYMENT_SESSION.md"
    "VPS_DEPENDENCY_FIX.md"
    "UPDATE_FEATURE_DOCUMENTATION.md"
)

echo -e "${BLUE}🗄️ Archiving obsolete documents...${NC}"
for doc in "${OBSOLETE_DOCS[@]}"; do
    if [[ -f "docs/$doc" ]]; then
        mv "docs/$doc" "docs/archive/obsolete-$(date +%Y%m%d)/"
        echo -e "${GREEN}✅ Archived $doc${NC}"
    fi
done

# Create README for archive
cat > "docs/archive/obsolete-$(date +%Y%m%d)/README.md" << 'EOF'
# Obsolete Documentation Archive

This directory contains documentation that has been superseded by the consolidated documentation structure.

## Replacement Documents

- **VPS_DEPLOYMENT.md** → `../DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md`
- **CLOUD_UPDATE_SUMMARY.md** → Outdated, no replacement needed
- **TECHNICAL_SUMMARY_AUR_DEPLOYMENT_SESSION.md** → Session notes, archived
- **VPS_DEPENDENCY_FIX.md** → Specific fix, archived
- **UPDATE_FEATURE_DOCUMENTATION.md** → `../USER_DOCUMENTATION/FEATURES_GUIDE.md`

## Archive Date
$(date)

These documents are kept for historical reference but should NOT be used.
EOF

echo -e "${GREEN}✅ Created archive README${NC}"

# Create consolidation status file
cat > "docs/CONSOLIDATION_STATUS.md" << 'EOF'
# Documentation Consolidation Status

## Consolidation Progress

### ✅ Completed
- [x] Directory structure created
- [x] Obsolete documents archived
- [x] Legal documents organized

### 🔄 In Progress
- [ ] Create consolidated SYSTEM_ARCHITECTURE.md
- [ ] Create consolidated INSTALLATION_GUIDE.md
- [ ] Create consolidated FEATURES_GUIDE.md
- [ ] Create consolidated INFRASTRUCTURE_GUIDE.md
- [ ] Create consolidated RELEASE_NOTES.md

### 📋 Pending Manual Review
- [ ] Review and merge architecture documents
- [ ] Review and merge installation guides
- [ ] Review and merge release documentation
- [ ] Update README.md references
- [ ] Update cross-references in all documents

## Target Structure

```
docs/
├── DEPLOYMENT/
│   ├── COMPLETE_DEPLOYMENT_WORKFLOW.md ✅
│   ├── DEPLOYMENT_WORKFLOW_DIAGRAM.md ✅
│   └── VERSIONING_STRATEGY.md ✅
├── ARCHITECTURE/
│   └── SYSTEM_ARCHITECTURE.md 🔄
├── INSTALLATION/
│   └── INSTALLATION_GUIDE.md 🔄
├── USER_DOCUMENTATION/
│   ├── USER_GUIDE.md 🔄
│   └── FEATURES_GUIDE.md 🔄
├── OPERATIONS/
│   ├── SELF_HOSTING.md ✅
│   └── INFRASTRUCTURE_GUIDE.md 🔄
├── RELEASE/
│   └── RELEASE_NOTES.md 🔄
├── LEGAL/
│   ├── PRIVACY.md ✅
│   └── TERMS.md ✅
└── archive/
    └── obsolete-YYYYMMDD/ ✅
```

## Consolidation Benefits

- **57% Reduction**: From 35+ documents to 15 documents
- **Clear Hierarchy**: Logical organization by topic
- **No Redundancy**: Single source of truth for each topic
- **Better Discoverability**: Intuitive directory structure
- **Maintainability**: Easier to keep documentation current

## Next Steps

1. Create consolidated documents using content from multiple sources
2. Update all cross-references
3. Update README.md documentation section
4. Test all links and references
5. Archive remaining redundant documents

EOF

echo -e "${GREEN}✅ Created consolidation status document${NC}"

echo ""
echo -e "${BLUE}📊 Consolidation Summary${NC}"
echo -e "${BLUE}========================${NC}"
echo -e "${GREEN}✅ Directory structure created${NC}"
echo -e "${GREEN}✅ Legal documents organized${NC}"
echo -e "${GREEN}✅ Obsolete documents archived${NC}"
echo -e "${YELLOW}🔄 Manual consolidation required for:${NC}"
echo -e "   - Architecture documents (5 → 1)"
echo -e "   - Installation guides (4 → 1)"
echo -e "   - Release documentation (6 → 1)"
echo -e "   - Technical implementation (4 → 1)"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo -e "1. Review docs/CONSOLIDATION_STATUS.md"
echo -e "2. Create consolidated documents manually"
echo -e "3. Update cross-references"
echo -e "4. Update README.md"
echo ""
echo -e "${GREEN}🎯 Target: 57% reduction (35+ → 15 documents)${NC}"
