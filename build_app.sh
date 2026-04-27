#!/bin/bash

# DuoduoManager build script
# Builds separate arm64 and x86_64 app bundles, each with matching Node.js runtime.

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Project config
APP_NAME="DuoduoManager"
APP_BUNDLE="${APP_NAME}.app"

# Version from project.yml (Info.plist uses Xcode build variables, not readable at script time)
VERSION=$(grep 'MARKETING_VERSION:' project.yml | sed 's/.*: *//')

# Output directories
DIST_DIR="dist"
WITH_NODE_SUFFIX="with-nodejs"
UNIVERSAL_LITE_VARIANT="universal-lite"
ALL_VARIANTS=("arm64-${WITH_NODE_SUFFIX}" "x86_64-${WITH_NODE_SUFFIX}" "${UNIVERSAL_LITE_VARIANT}")

# Node.js config
NODE_VERSION="24"
NODE_CACHE_DIR=".node-cache"

echo -e "${GREEN}=== DuoduoManager Build ===${NC}"
echo "Version: ${VERSION}"

variant_app_path() {
    local variant="$1"
    echo "${DIST_DIR}/${APP_NAME}-${variant}/${APP_BUNDLE}"
}

variant_dmg_path() {
    local variant="$1"
    echo "${DIST_DIR}/${APP_NAME}-${VERSION}-${variant}.dmg"
}

runtime_mode_for_variant() {
    local include_node="$1"
    if [ "$include_node" = "yes" ]; then
        echo "bundled"
    else
        echo "system"
    fi
}

bundle_node_runtime() {
    local node_arch="$1"
    local app_path="$2"
    local node_dir

    node_dir=$(extract_node "$node_arch")
    mkdir -p "${app_path}/Contents/Resources/node"
    tar -cf - -C "$node_dir" . | tar -xf - -C "${app_path}/Contents/Resources/node"
    rm -rf "$node_dir"
}

print_app_artifacts() {
    echo "  arm64-with-nodejs:  $(variant_app_path "arm64-${WITH_NODE_SUFFIX}")"
    echo "  x86_64-with-nodejs: $(variant_app_path "x86_64-${WITH_NODE_SUFFIX}")"
    echo "  universal-lite:     $(variant_app_path "${UNIVERSAL_LITE_VARIANT}")"
}

print_dmg_artifacts() {
    echo "  arm64-with-nodejs DMG:  $(variant_dmg_path "arm64-${WITH_NODE_SUFFIX}")"
    echo "  x86_64-with-nodejs DMG: $(variant_dmg_path "x86_64-${WITH_NODE_SUFFIX}")"
    echo "  universal-lite DMG:     $(variant_dmg_path "${UNIVERSAL_LITE_VARIANT}")"
}

# Download Node.js if not cached
ensure_node() {
    echo -e "${GREEN}Checking Node.js ${NODE_VERSION} LTS...${NC}"

    mkdir -p "${NODE_CACHE_DIR}"

    local NODE_FULL_VERSION
    NODE_FULL_VERSION=$(curl -sL "https://nodejs.org/dist/latest-v${NODE_VERSION}.x/" | grep -oE 'node-v([0-9]+\.[0-9]+\.[0-9]+)-darwin-arm64\.tar\.gz' | head -1 | sed -E 's/node-v([0-9]+\.[0-9]+\.[0-9]+)-.*/\1/')

    if [ -z "$NODE_FULL_VERSION" ]; then
        echo -e "${RED}Failed to detect Node.js ${NODE_VERSION} LTS version${NC}"
        exit 1
    fi

    echo "Node.js version: ${NODE_FULL_VERSION}"

    local arm64_file="${NODE_CACHE_DIR}/node-v${NODE_FULL_VERSION}-darwin-arm64.tar.gz"
    if [ ! -f "$arm64_file" ]; then
        echo "Downloading arm64..."
        curl -L "https://nodejs.org/dist/v${NODE_FULL_VERSION}/node-v${NODE_FULL_VERSION}-darwin-arm64.tar.gz" -o "$arm64_file"
    fi

    local x64_file="${NODE_CACHE_DIR}/node-v${NODE_FULL_VERSION}-darwin-x64.tar.gz"
    if [ ! -f "$x64_file" ]; then
        echo "Downloading x86_64..."
        curl -L "https://nodejs.org/dist/v${NODE_FULL_VERSION}/node-v${NODE_FULL_VERSION}-darwin-x64.tar.gz" -o "$x64_file"
    fi

    echo -e "${GREEN}Node.js ${NODE_FULL_VERSION} ready in ${NODE_CACHE_DIR}${NC}"
}

# Extract cached Node.js for a given arch, prints the extract path
extract_node() {
    local arch="$1"
    local node_full_version
    node_full_version=$(basename "$(ls "${NODE_CACHE_DIR}"/node-v*-darwin-arm64.tar.gz 2>/dev/null | head -1)" | sed -E 's/node-v([0-9]+\.[0-9]+\.[0-9]+)-.*/\1/')

    local arch_suffix="x64"
    [ "$arch" = "arm64" ] && arch_suffix="arm64"

    local extract_dir="${NODE_CACHE_DIR}/.extract-${arch}"
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"
    tar -xzf "${NODE_CACHE_DIR}/node-v${node_full_version}-darwin-${arch_suffix}.tar.gz" -C "$extract_dir" --strip-components=1
    echo "$extract_dir"
}

# Check signing config
check_signing_config() {
    if [ -f ".secret.env" ]; then
        source ./.secret.env
    fi

    if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ]; then
        echo -e "${YELLOW}Signing/notarization env is incomplete${NC}"
        echo "  Provide APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, and APPLE_TEAM_ID via env or .secret.env"
        return 1
    fi

    if [ -z "${APPLE_SIGNING_IDENTITY:-}" ] && [ -n "${APPLE_TEAM_NAME:-}" ]; then
        APPLE_SIGNING_IDENTITY="${APPLE_TEAM_NAME}"
    fi

    if [ -z "${APPLE_SIGNING_IDENTITY:-}" ]; then
        echo -e "${YELLOW}APPLE_SIGNING_IDENTITY is missing${NC}"
        return 1
    fi

    echo -e "${GREEN}Signing config loaded${NC}"
    return 0
}

# Build app bundle for a variant, based on the xcodebuild-produced .app
build_variant() {
    local variant="$1"
    local source_app="$2"
    local include_node="$3"
    local node_arch="$4"
    local app_path
    app_path=$(variant_app_path "$variant")

    echo -e "${GREEN}Building ${variant}...${NC}"

    # Start from the xcodebuild-produced .app (has correct Info.plist, resources, bundles)
    rm -rf "$app_path"
    mkdir -p "$(dirname "$app_path")"
    cp -R "$source_app" "$app_path"
    chmod -R u+w "$app_path"

    # Mark runtime mode and build variant in Info.plist
    local info_plist_path="${app_path}/Contents/Info.plist"
    local runtime_mode
    runtime_mode=$(runtime_mode_for_variant "$include_node")
    /usr/libexec/PlistBuddy -c "Delete :DuoduoNodeRuntimeMode" "$info_plist_path" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :DuoduoNodeRuntimeMode string $runtime_mode" "$info_plist_path"
    /usr/libexec/PlistBuddy -c "Delete :DuoduoBuildVariant" "$info_plist_path" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :DuoduoBuildVariant string $variant" "$info_plist_path"

    # Inject Sparkle EdDSA public key if available
    if [ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]; then
        /usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$info_plist_path" >/dev/null 2>&1 || true
        /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string ${SPARKLE_PUBLIC_ED_KEY}" "$info_plist_path"
    fi

    # Bundle matching-arch Node.js runtime (use tar to preserve symlinks)
    if [ "$include_node" = "yes" ]; then
        bundle_node_runtime "$node_arch" "${app_path}"
    fi

    echo -e "${GREEN}${variant} bundle created: ${app_path}${NC}"
}

# Build both architectures + universal-lite
build_all() {
    rm -rf "${DIST_DIR}"
    mkdir -p "${DIST_DIR}"

    ensure_node
    xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Release -arch arm64 -derivedDataPath .build/arm64 build
    xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Release -arch x86_64 -derivedDataPath .build/x64 build

    local arm64_app=".build/arm64/Build/Products/Release/${APP_NAME}.app"
    local x64_app=".build/x64/Build/Products/Release/${APP_NAME}.app"
    local universal_app_path
    universal_app_path=$(variant_app_path "${UNIVERSAL_LITE_VARIANT}")

    build_variant "arm64-${WITH_NODE_SUFFIX}" "$arm64_app" "yes" "arm64"
    build_variant "x86_64-${WITH_NODE_SUFFIX}" "$x64_app" "yes" "x86_64"

    build_variant "$UNIVERSAL_LITE_VARIANT" "$arm64_app" "no" "arm64"
    local arm64_binary="${arm64_app}/Contents/MacOS/${APP_NAME}"
    local x64_binary="${x64_app}/Contents/MacOS/${APP_NAME}"
    lipo -create "$arm64_binary" "$x64_binary" -output "${universal_app_path}/Contents/MacOS/${APP_NAME}"
    chmod +x "${universal_app_path}/Contents/MacOS/${APP_NAME}"
    echo -e "${GREEN}${UNIVERSAL_LITE_VARIANT} binary merged with lipo${NC}"
}

# Sign app for a variant
sign_app_variant() {
    local variant="$1"
    local app_path
    app_path=$(variant_app_path "$variant")

    echo -e "${GREEN}Signing ${variant}...${NC}"
    chmod -R u+w "$app_path"
    xattr -cr "$app_path"

    codesign --force --options runtime \
        --sign "${APPLE_SIGNING_IDENTITY}" \
        --entitlements "entitlements.mac.plist" \
        --deep "$app_path"

    codesign --verify --deep --strict "$app_path"
    echo -e "${GREEN}${variant} signing succeeded${NC}"
}

# Notarize DMG for a variant
notarize_dmg_variant() {
    local variant="$1"
    local dmg_path
    dmg_path=$(variant_dmg_path "$variant")

    echo -e "${GREEN}Notarizing ${variant}...${NC}"

    echo "Submitting ${variant} notarization request (may take a few minutes)..."
    xcrun notarytool submit "$dmg_path" \
        --wait \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
        --team-id "${APPLE_TEAM_ID}"

    echo -e "${GREEN}${variant} notarization succeeded${NC}"
    xcrun stapler staple "$dmg_path"
    spctl --assess --type open --context context:primary-signature --verbose "$dmg_path"
    echo -e "${GREEN}${variant} DMG stapled and verified${NC}"
}

# Create DMG for a variant
create_dmg_variant() {
    local variant="$1"
    local app_path
    local dmg_path
    app_path=$(variant_app_path "$variant")
    dmg_path=$(variant_dmg_path "$variant")

    echo -e "${GREEN}Creating ${variant} DMG...${NC}"

    local volname="${APP_NAME}-${VERSION}-${variant}"

    # Unmount any previously mounted volume with the same name
    hdiutil detach "/Volumes/${volname}" >/dev/null 2>&1 || true

    local temp_dir="${DIST_DIR}/temp_dmg_${variant}"
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    cp -R "$app_path" "$temp_dir/"

    if command -v create-dmg &> /dev/null; then
        echo "Using create-dmg for styled ${variant} DMG..."

        [ -f "$dmg_path" ] && rm "$dmg_path"

        create-dmg \
            --text-size 13 \
            --volname "${volname}" \
            --volicon "${app_path}/Contents/Resources/AppIcon.icns" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "${APP_BUNDLE}" 150 150 \
            --app-drop-link 450 150 \
            --hide-extension "${APP_BUNDLE}" \
            --no-internet-enable \
            --format ULFO \
            "$dmg_path" \
            "$temp_dir" || {
            echo -e "${YELLOW}create-dmg failed, falling back to simple mode${NC}"
            ln -sf /Applications "$temp_dir/Applications"
            hdiutil create -volname "${volname}" \
                -srcfolder "$temp_dir" \
                -ov -format UDZO "$dmg_path"
        }
    else
        echo "Using simple DMG mode..."
        ln -sf /Applications "$temp_dir/Applications"
        hdiutil create -volname "${volname}" \
            -srcfolder "$temp_dir" \
            -ov -format UDZO "$dmg_path"
    fi

    rm -rf "$temp_dir"

    echo -e "${GREEN}${variant} DMG: ${dmg_path}${NC}"
}

sign_dmg_variant() {
    local variant="$1"
    local dmg_path
    dmg_path=$(variant_dmg_path "$variant")

    echo -e "${GREEN}Signing ${variant} DMG...${NC}"
    codesign --force --sign "${APPLE_SIGNING_IDENTITY}" "$dmg_path"
    codesign --verify --verbose "$dmg_path"
    echo -e "${GREEN}${variant} DMG signing succeeded${NC}"
}

# Build only (no signing)
build_only() {
    build_all
    echo -e "${GREEN}Build complete${NC}"
    print_app_artifacts
}

# Full release flow
release() {
    if check_signing_config; then
        build_all
        for variant in "${ALL_VARIANTS[@]}"; do
            sign_app_variant "$variant"
            create_dmg_variant "$variant"
            sign_dmg_variant "$variant"
            notarize_dmg_variant "$variant"
        done
        echo -e "${GREEN}=== Release complete ===${NC}"
        print_dmg_artifacts
    else
        echo -e "${RED}Signing config required for release${NC}"
        exit 1
    fi
}

# Show help
show_help() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  build     - Build arm64/x86_64(with-nodejs) + universal-lite(no-node) app bundles"
    echo "  release   - Full release flow (build + sign + notarize + DMG for all variants)"
    echo "  sign      - Sign existing app bundles"
    echo "  dmg       - Create DMGs for all variants"
    echo "  node      - Download Node.js 24 LTS to cache (no build)"
    echo "  help      - Show this help"
}

# Main
case "${1:-build}" in
    build)
        build_only
        ;;
    release)
        release
        ;;
    sign)
        check_signing_config
        for variant in "${ALL_VARIANTS[@]}"; do
            sign_app_variant "$variant"
        done
        ;;
    dmg)
        for variant in "${ALL_VARIANTS[@]}"; do
            create_dmg_variant "$variant"
        done
        ;;
    node)
        ensure_node
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
