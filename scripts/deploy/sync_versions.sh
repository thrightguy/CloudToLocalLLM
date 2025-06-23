#!/bin/bash
# scripts/deploy/sync_versions.sh
# Ensures all version references match pubspec.yaml

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

echo -e "${BLUE}ðŸ”„ Synchronizing all version references...${NC}"

# Check if version manager exists
if [[ ! -f "scripts/version_manager.sh" ]]; then
    echo -e "${RED}âŒ Version manager script not found!${NC}"
    exit 1
fi

# Get version information from pubspec.yaml
PUBSPEC_VERSION=$(./scripts/version_manager.sh get-semantic)
PUBSPEC_BUILD=$(./scripts/version_manager.sh get-build)
FULL_VERSION=$(./scripts/version_manager.sh get)

if [[ -z "$PUBSPEC_VERSION" || -z "$PUBSPEC_BUILD" ]]; then
    echo -e "${RED}âŒ Failed to get version from pubspec.yaml${NC}"
    exit 1
fi

echo -e "${YELLOW}ðŸ“‹ Current version: $FULL_VERSION${NC}"

# Update assets/version.json
echo -e "${BLUE}ðŸ“ Updating assets/version.json...${NC}"
cat > assets/version.json << EOF
{
  "version": "$PUBSPEC_VERSION",
  "build_number": "$PUBSPEC_BUILD",
  "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "git_commit": "$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
}
EOF

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}âœ… Updated assets/version.json${NC}"
else
    echo -e "${RED}âŒ Failed to update assets/version.json${NC}"
    exit 1
fi

# Update AUR PKGBUILD
if [[ -f "aur-package/PKGBUILD" ]]; then
    echo -e "${BLUE}ðŸ“ Updating AUR PKGBUILD...${NC}"

    # Create backup
    cp "aur-package/PKGBUILD" "aur-package/PKGBUILD.backup"

    # Update pkgver
    sed -i "s/^pkgver=.*/pkgver=$PUBSPEC_VERSION/" aur-package/PKGBUILD

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}âœ… Updated AUR PKGBUILD pkgver to $PUBSPEC_VERSION${NC}"
    else
        echo -e "${RED}âŒ Failed to update AUR PKGBUILD${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}âš ï¸  AUR PKGBUILD not found, skipping...${NC}"
fi

# Update lib/shared/lib/version.dart
if [[ -f "lib/shared/lib/version.dart" ]]; then
    echo -e "${BLUE}ðŸ“ Updating lib/shared/lib/version.dart...${NC}"

    # Create backup
    cp "lib/shared/lib/version.dart" "lib/shared/lib/version.dart.backup"

    # Generate build timestamp and use existing build number from pubspec.yaml
    BUILD_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    # Use the build number from pubspec.yaml to maintain consistency
    BUILD_NUMBER_INT="$PUBSPEC_BUILD"

    # Update all version constants
    sed -i "s/static const String mainAppVersion = '[^']*';/static const String mainAppVersion = '$PUBSPEC_VERSION';/" lib/shared/lib/version.dart
    sed -i "s/static const int mainAppBuildNumber = [0-9]*;/static const int mainAppBuildNumber = $BUILD_NUMBER_INT;/" lib/shared/lib/version.dart
    sed -i "s/static const String tunnelManagerVersion = '[^']*';/static const String tunnelManagerVersion = '$PUBSPEC_VERSION';/" lib/shared/lib/version.dart
    sed -i "s/static const int tunnelManagerBuildNumber = [0-9]*;/static const int tunnelManagerBuildNumber = $BUILD_NUMBER_INT;/" lib/shared/lib/version.dart
    sed -i "s/static const String sharedLibraryVersion = '[^']*';/static const String sharedLibraryVersion = '$PUBSPEC_VERSION';/" lib/shared/lib/version.dart
    sed -i "s/static const int sharedLibraryBuildNumber = [0-9]*;/static const int sharedLibraryBuildNumber = $BUILD_NUMBER_INT;/" lib/shared/lib/version.dart
    sed -i "s/static const String buildTimestamp = '[^']*';/static const String buildTimestamp = '$BUILD_TIMESTAMP';/" lib/shared/lib/version.dart

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}âœ… Updated lib/shared/lib/version.dart to $PUBSPEC_VERSION${NC}"
    else
        echo -e "${RED}âŒ Failed to update lib/shared/lib/version.dart${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}âš ï¸  lib/shared/lib/version.dart not found, skipping...${NC}"
fi

# Update lib/shared/pubspec.yaml
if [[ -f "lib/shared/pubspec.yaml" ]]; then
    echo -e "${BLUE}ðŸ“ Updating lib/shared/pubspec.yaml...${NC}"

    # Create backup
    cp "lib/shared/pubspec.yaml" "lib/shared/pubspec.yaml.backup"

    # Update version line
    sed -i "s/^version:.*/version: $FULL_VERSION/" lib/shared/pubspec.yaml

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}âœ… Updated lib/shared/pubspec.yaml to $FULL_VERSION${NC}"
    else
        echo -e "${RED}âŒ Failed to update lib/shared/pubspec.yaml${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}âš ï¸  lib/shared/pubspec.yaml not found, skipping...${NC}"
fi

# Verify synchronization
echo -e "${BLUE}ðŸ” Verifying version synchronization...${NC}"

# Check assets/version.json
ASSETS_VERSION=$(grep '"version"' assets/version.json | cut -d'"' -f4)
if [[ "$ASSETS_VERSION" = "$PUBSPEC_VERSION" ]]; then
    echo -e "${GREEN}âœ… assets/version.json: $ASSETS_VERSION${NC}"
else
    echo -e "${RED}âŒ assets/version.json version mismatch: $ASSETS_VERSION != $PUBSPEC_VERSION${NC}"
    exit 1
fi

# Check AUR PKGBUILD if it exists
if [[ -f "aur-package/PKGBUILD" ]]; then
    AUR_VERSION=$(grep "^pkgver=" aur-package/PKGBUILD | cut -d'=' -f2)
    if [[ "$AUR_VERSION" = "$PUBSPEC_VERSION" ]]; then
        echo -e "${GREEN}âœ… AUR PKGBUILD: $AUR_VERSION${NC}"
    else
        echo -e "${RED}âŒ AUR PKGBUILD version mismatch: $AUR_VERSION != $PUBSPEC_VERSION${NC}"
        exit 1
    fi
fi

# Check lib/shared/lib/version.dart if it exists
if [[ -f "lib/shared/lib/version.dart" ]]; then
    SHARED_VERSION=$(grep "static const String mainAppVersion = " lib/shared/lib/version.dart | cut -d"'" -f2)
    if [[ "$SHARED_VERSION" = "$PUBSPEC_VERSION" ]]; then
        echo -e "${GREEN}âœ… lib/shared/lib/version.dart: $SHARED_VERSION${NC}"
    else
        echo -e "${RED}âŒ lib/shared/lib/version.dart version mismatch: $SHARED_VERSION != $PUBSPEC_VERSION${NC}"
        exit 1
    fi
fi

# Check lib/shared/pubspec.yaml if it exists
if [[ -f "lib/shared/pubspec.yaml" ]]; then
    SHARED_PUBSPEC_VERSION=$(grep "^version:" lib/shared/pubspec.yaml | cut -d':' -f2 | tr -d ' ' | cut -d'+' -f1)
    if [[ "$SHARED_PUBSPEC_VERSION" = "$PUBSPEC_VERSION" ]]; then
        echo -e "${GREEN}âœ… lib/shared/pubspec.yaml: $SHARED_PUBSPEC_VERSION${NC}"
    else
        echo -e "${RED}âŒ lib/shared/pubspec.yaml version mismatch: $SHARED_PUBSPEC_VERSION != $PUBSPEC_VERSION${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}ðŸŽ‰ All versions synchronized to $FULL_VERSION${NC}"
echo -e "${BLUE}ðŸ“‹ Summary:${NC}"
echo -e "  pubspec.yaml: $FULL_VERSION"
echo -e "  assets/version.json: $PUBSPEC_VERSION"
if [[ -f "aur-package/PKGBUILD" ]]; then
    echo -e "  AUR PKGBUILD: $AUR_VERSION"
fi
if [[ -f "lib/shared/lib/version.dart" ]]; then
    echo -e "  lib/shared/lib/version.dart: $SHARED_VERSION"
fi
if [[ -f "lib/shared/pubspec.yaml" ]]; then
    echo -e "  lib/shared/pubspec.yaml: $SHARED_PUBSPEC_VERSION"
fi

echo -e "${YELLOW}ðŸ’¡ Next steps:${NC}"
echo -e "  1. Review changes: git diff"
echo -e "  2. Commit changes: git add . && git commit -m 'Sync versions to $FULL_VERSION'"
echo -e "  3. Continue with deployment workflow"
