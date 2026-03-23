#!/bin/bash

# DuoduoManager build script
# Builds separate arm64 and x86_64 app bundles, each with matching Node.js runtime.

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Project config
APP_NAME="DuoduoManager"
APP_BUNDLE="${APP_NAME}.app"
TEMPLATE_DIR="${APP_NAME}.app-template"
INFO_PLIST="${TEMPLATE_DIR}/Contents/Info.plist"

# Version from Info.plist
VERSION=$(grep -A1 "CFBundleShortVersionString" "$INFO_PLIST" | grep "<string>" | sed -E 's/.*<string>(.*)<\/string>.*/\1/')

# Output directories
DIST_DIR="dist"

# Node.js config
NODE_VERSION="24"
NODE_CACHE_DIR=".node-cache"

echo -e "${GREEN}=== DuoduoManager Build ===${NC}"
echo "Version: ${VERSION}"

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

    local ARM64_FILE="${NODE_CACHE_DIR}/node-v${NODE_FULL_VERSION}-darwin-arm64.tar.gz"
    if [ ! -f "$ARM64_FILE" ]; then
        echo "Downloading arm64..."
        curl -L "https://nodejs.org/dist/v${NODE_FULL_VERSION}/node-v${NODE_FULL_VERSION}-darwin-arm64.tar.gz" -o "$ARM64_FILE"
    fi

    local X64_FILE="${NODE_CACHE_DIR}/node-v${NODE_FULL_VERSION}-darwin-x64.tar.gz"
    if [ ! -f "$X64_FILE" ]; then
        echo "Downloading x86_64..."
        curl -L "https://nodejs.org/dist/v${NODE_FULL_VERSION}/node-v${NODE_FULL_VERSION}-darwin-x64.tar.gz" -o "$X64_FILE"
    fi

    echo -e "${GREEN}Node.js ${NODE_FULL_VERSION} ready in ${NODE_CACHE_DIR}${NC}"
}

# Extract cached Node.js for a given arch, prints the extract path
extract_node() {
    local ARCH="$1"
    local NODE_FULL_VERSION
    NODE_FULL_VERSION=$(ls "${NODE_CACHE_DIR}"/node-v*-darwin-arm64.tar.gz 2>/dev/null | head -1 | xargs -I{} basename {} | sed -E 's/node-v([0-9]+\.[0-9]+\.[0-9]+)-.*/\1/')

    local EXTRACT_DIR="${NODE_CACHE_DIR}/.extract-${ARCH}"
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    tar -xzf "${NODE_CACHE_DIR}/node-v${NODE_FULL_VERSION}-darwin-${ARCH}.tar.gz" -C "$EXTRACT_DIR" --strip-components=1
    echo "$EXTRACT_DIR"
}

# Check signing config
check_signing_config() {
    if [ -f ".secret.env" ]; then
        source ./.secret.env
        echo -e "${GREEN}Signing config loaded${NC}"
        return 0
    else
        echo -e "${YELLOW}No .secret.env found, skipping signing and notarization${NC}"
        echo "  Copy secret.env.example to .secret.env and fill in config to enable signing"
        return 1
    fi
}

# Build app bundle for a specific arch
build_for_arch() {
    local ARCH="$1"
    local APP_PATH="${DIST_DIR}/${APP_NAME}-${ARCH}/${APP_BUNDLE}"

    echo -e "${GREEN}Building ${ARCH}...${NC}"

    swift build -c release --arch "$ARCH"

    mkdir -p "$(dirname "$APP_PATH")"
    cp -r "${TEMPLATE_DIR}" "$APP_PATH"

    local BINARY=".build/${ARCH}-apple-macosx/release/${APP_NAME}"
    cp "$BINARY" "${APP_PATH}/Contents/MacOS/"
    chmod +x "${APP_PATH}/Contents/MacOS/${APP_NAME}"
    echo -n "APPL????" > "${APP_PATH}/Contents/PkgInfo"

    mkdir -p "${APP_PATH}/Contents/Resources"
    cp -r Sources/Resources/*.lproj "${APP_PATH}/Contents/Resources/"

    # Bundle matching-arch Node.js runtime (use tar to preserve symlinks)
    local NODE_DIR
    NODE_DIR=$(extract_node "$ARCH")
    mkdir -p "${APP_PATH}/Contents/Resources/node"
    tar -cf - -C "$NODE_DIR" . | tar -xf - -C "${APP_PATH}/Contents/Resources/node"
    rm -rf "$NODE_DIR"

    echo -e "${GREEN}${ARCH} bundle created: ${APP_PATH}${NC}"
}

# Build both architectures
build_all() {
    rm -rf "${DIST_DIR}"
    mkdir -p "${DIST_DIR}"

    ensure_node
    build_for_arch arm64
    build_for_arch x86_64
}

# Sign app for a specific arch
sign_app_arch() {
    local ARCH="$1"
    local APP_PATH="${DIST_DIR}/${APP_NAME}-${ARCH}/${APP_BUNDLE}"

    echo -e "${GREEN}Signing ${ARCH}...${NC}"
    xattr -cr "$APP_PATH"

    codesign --force --options runtime \
        --sign "${APPLE_TEAM_NAME}" \
        --entitlements "entitlements.mac.plist" \
        --deep "$APP_PATH"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${ARCH} signing succeeded${NC}"
    else
        echo -e "${RED}${ARCH} signing failed${NC}"
        exit 1
    fi
}

# Notarize app for a specific arch
notarize_app_arch() {
    local ARCH="$1"
    local APP_PATH="${DIST_DIR}/${APP_NAME}-${ARCH}/${APP_BUNDLE}"
    local ZIP_PATH="${DIST_DIR}/${APP_NAME}-${ARCH}.zip"

    echo -e "${GREEN}Notarizing ${ARCH}...${NC}"

    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

    echo "Submitting ${ARCH} notarization request (may take a few minutes)..."
    xcrun notarytool submit "$ZIP_PATH" \
        --wait \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
        --team-id "${APPLE_TEAM_ID}"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${ARCH} notarization succeeded${NC}"
        xcrun stapler staple "$APP_PATH"
        echo -e "${GREEN}${ARCH} staple attached${NC}"
    else
        echo -e "${RED}${ARCH} notarization failed${NC}"
        exit 1
    fi

    rm "$ZIP_PATH"
}

# Create DMG for a specific arch
create_dmg_arch() {
    local ARCH="$1"
    local APP_PATH="${DIST_DIR}/${APP_NAME}-${ARCH}/${APP_BUNDLE}"
    local DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}-${ARCH}.dmg"

    echo -e "${GREEN}Creating ${ARCH} DMG...${NC}"

    local TEMP_DIR="${DIST_DIR}/temp_dmg_${ARCH}"
    mkdir -p "$TEMP_DIR"
    cp -r "$APP_PATH" "$TEMP_DIR/"

    if command -v create-dmg &> /dev/null; then
        echo "Using create-dmg for styled ${ARCH} DMG..."

        [ -f "$DMG_PATH" ] && rm "$DMG_PATH"

        create-dmg \
            --text-size 13 \
            --volname "${APP_NAME}-${VERSION}-${ARCH}" \
            --volicon "${APP_PATH}/Contents/Resources/AppIcon.icns" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "${APP_BUNDLE}" 150 190 \
            --app-drop-link 450 190 \
            --no-internet-enable \
            --format UDZO \
            "$DMG_PATH" \
            "$TEMP_DIR" || {
            echo -e "${YELLOW}create-dmg failed, falling back to simple mode${NC}"
            ln -sf /Applications "$TEMP_DIR/Applications"
            hdiutil create -volname "${APP_NAME}-${VERSION}-${ARCH}" \
                -srcfolder "$TEMP_DIR" \
                -ov -format UDZO "$DMG_PATH"
        }
    else
        echo "Using simple DMG mode..."
        ln -sf /Applications "$TEMP_DIR/Applications"
        hdiutil create -volname "${APP_NAME}-${VERSION}-${ARCH}" \
            -srcfolder "$TEMP_DIR" \
            -ov -format UDZO "$DMG_PATH"
    fi

    rm -rf "$TEMP_DIR"

    echo -e "${GREEN}${ARCH} DMG: ${DMG_PATH}${NC}"
}

# Build only (no signing)
build_only() {
    build_all
    echo -e "${GREEN}Build complete${NC}"
    echo "  arm64:  ${DIST_DIR}/${APP_NAME}-arm64/${APP_BUNDLE}"
    echo "  x86_64: ${DIST_DIR}/${APP_NAME}-x86_64/${APP_BUNDLE}"
}

# Full release flow
release() {
    if check_signing_config; then
        build_all
        for ARCH in arm64 x86_64; do
            sign_app_arch "$ARCH"
            notarize_app_arch "$ARCH"
            create_dmg_arch "$ARCH"
        done
        echo -e "${GREEN}=== Release complete ===${NC}"
        echo "  arm64 DMG:  ${DIST_DIR}/${APP_NAME}-${VERSION}-arm64.dmg"
        echo "  x86_64 DMG: ${DIST_DIR}/${APP_NAME}-${VERSION}-x86_64.dmg"
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
    echo "  build     - Build arm64 + x86_64 app bundles (no signing)"
    echo "  release   - Full release flow (build + sign + notarize + DMG for both archs)"
    echo "  sign      - Sign existing app bundles"
    echo "  dmg       - Create DMGs for both architectures"
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
        for ARCH in arm64 x86_64; do
            sign_app_arch "$ARCH"
        done
        ;;
    dmg)
        for ARCH in arm64 x86_64; do
            create_dmg_arch "$ARCH"
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
