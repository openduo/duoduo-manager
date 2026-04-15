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
WITH_NODE_SUFFIX="with-nodejs"
UNIVERSAL_LITE_VARIANT="universal-lite"

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

    local ARCH_SUFFIX="x64"
    [ "$ARCH" = "arm64" ] && ARCH_SUFFIX="arm64"

    local EXTRACT_DIR="${NODE_CACHE_DIR}/.extract-${ARCH}"
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    tar -xzf "${NODE_CACHE_DIR}/node-v${NODE_FULL_VERSION}-darwin-${ARCH_SUFFIX}.tar.gz" -C "$EXTRACT_DIR" --strip-components=1
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

# Build app bundle for a variant
build_variant() {
    local VARIANT="$1"
    local BINARY_PATH="$2"
    local INCLUDE_NODE="$3"
    local NODE_ARCH="$4"
    local CC_READER_BUNDLE_SOURCE="$5"
    local APP_PATH="${DIST_DIR}/${APP_NAME}-${VARIANT}/${APP_BUNDLE}"

    echo -e "${GREEN}Building ${VARIANT}...${NC}"

    mkdir -p "$(dirname "$APP_PATH")"
    cp -r "${TEMPLATE_DIR}" "$APP_PATH"

    cp "$BINARY_PATH" "${APP_PATH}/Contents/MacOS/${APP_NAME}"
    chmod +x "${APP_PATH}/Contents/MacOS/${APP_NAME}"
    echo -n "APPL????" > "${APP_PATH}/Contents/PkgInfo"

    # Mark runtime mode in Info.plist so app logic doesn't rely on stale files.
    local INFO_PLIST_PATH="${APP_PATH}/Contents/Info.plist"
    local RUNTIME_MODE="system"
    [ "$INCLUDE_NODE" = "yes" ] && RUNTIME_MODE="bundled"
    /usr/libexec/PlistBuddy -c "Delete :DuoduoNodeRuntimeMode" "$INFO_PLIST_PATH" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :DuoduoNodeRuntimeMode string $RUNTIME_MODE" "$INFO_PLIST_PATH"

    mkdir -p "${APP_PATH}/Contents/Resources"
    cp -r Sources/Resources/*.lproj "${APP_PATH}/Contents/Resources/"

    local CC_READER_BUNDLE_DIR="${APP_PATH}/CCReaderKit_CCReaderKit.bundle"
    # Copy the SwiftPM-generated resource bundle verbatim.
    # Reconstructing it from checkout sources misses bundle metadata and can
    # behave differently between remote package and local path dependency modes.
    if [ -d "${CC_READER_BUNDLE_SOURCE}" ]; then
        rm -rf "${CC_READER_BUNDLE_DIR}"
        cp -R "${CC_READER_BUNDLE_SOURCE}" "${CC_READER_BUNDLE_DIR}"
    else
        echo -e "${YELLOW}Warning: CCReaderKit bundle not found at ${CC_READER_BUNDLE_SOURCE}${NC}"
    fi

    # Bundle matching-arch Node.js runtime (use tar to preserve symlinks)
    if [ "$INCLUDE_NODE" = "yes" ]; then
        local NODE_DIR
        NODE_DIR=$(extract_node "$NODE_ARCH")
        mkdir -p "${APP_PATH}/Contents/Resources/node"
        tar -cf - -C "$NODE_DIR" . | tar -xf - -C "${APP_PATH}/Contents/Resources/node"
        rm -rf "$NODE_DIR"
    fi

    echo -e "${GREEN}${VARIANT} bundle created: ${APP_PATH}${NC}"
}

# Build both architectures + universal-lite
build_all() {
    rm -rf "${DIST_DIR}"
    mkdir -p "${DIST_DIR}"

    ensure_node
    swift build -c release --arch arm64
    swift build -c release --arch x86_64

    local ARM64_BINARY=".build/arm64-apple-macosx/release/${APP_NAME}"
    local X64_BINARY=".build/x86_64-apple-macosx/release/${APP_NAME}"
    local ARM64_CC_READER_BUNDLE=".build/arm64-apple-macosx/release/CCReaderKit_CCReaderKit.bundle"
    local X64_CC_READER_BUNDLE=".build/x86_64-apple-macosx/release/CCReaderKit_CCReaderKit.bundle"
    local ARM64_VARIANT="arm64-${WITH_NODE_SUFFIX}"
    local X64_VARIANT="x86_64-${WITH_NODE_SUFFIX}"
    local UNIVERSAL_APP_PATH="${DIST_DIR}/${APP_NAME}-${UNIVERSAL_LITE_VARIANT}/${APP_BUNDLE}"

    build_variant "$ARM64_VARIANT" "$ARM64_BINARY" "yes" "arm64" "$ARM64_CC_READER_BUNDLE"
    build_variant "$X64_VARIANT" "$X64_BINARY" "yes" "x86_64" "$X64_CC_READER_BUNDLE"

    build_variant "$UNIVERSAL_LITE_VARIANT" "$ARM64_BINARY" "no" "arm64" "$ARM64_CC_READER_BUNDLE"
    lipo -create "$ARM64_BINARY" "$X64_BINARY" -output "${UNIVERSAL_APP_PATH}/Contents/MacOS/${APP_NAME}"
    chmod +x "${UNIVERSAL_APP_PATH}/Contents/MacOS/${APP_NAME}"
    echo -e "${GREEN}${UNIVERSAL_LITE_VARIANT} binary merged with lipo${NC}"
}

# Sign app for a variant
sign_app_variant() {
    local VARIANT="$1"
    local APP_PATH="${DIST_DIR}/${APP_NAME}-${VARIANT}/${APP_BUNDLE}"

    echo -e "${GREEN}Signing ${VARIANT}...${NC}"
    xattr -cr "$APP_PATH"

    codesign --force --options runtime \
        --sign "${APPLE_TEAM_NAME}" \
        --entitlements "entitlements.mac.plist" \
        --deep "$APP_PATH"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${VARIANT} signing succeeded${NC}"
    else
        echo -e "${RED}${VARIANT} signing failed${NC}"
        exit 1
    fi
}

# Notarize app for a variant
notarize_app_variant() {
    local VARIANT="$1"
    local APP_PATH="${DIST_DIR}/${APP_NAME}-${VARIANT}/${APP_BUNDLE}"
    local ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VARIANT}.zip"

    echo -e "${GREEN}Notarizing ${VARIANT}...${NC}"

    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

    echo "Submitting ${VARIANT} notarization request (may take a few minutes)..."
    xcrun notarytool submit "$ZIP_PATH" \
        --wait \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
        --team-id "${APPLE_TEAM_ID}"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${VARIANT} notarization succeeded${NC}"
        xcrun stapler staple "$APP_PATH"
        echo -e "${GREEN}${VARIANT} staple attached${NC}"
    else
        echo -e "${RED}${VARIANT} notarization failed${NC}"
        exit 1
    fi

    rm "$ZIP_PATH"
}

# Create DMG for a variant
create_dmg_variant() {
    local VARIANT="$1"
    local APP_PATH="${DIST_DIR}/${APP_NAME}-${VARIANT}/${APP_BUNDLE}"
    local DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}-${VARIANT}.dmg"

    echo -e "${GREEN}Creating ${VARIANT} DMG...${NC}"

    local VOLNAME="${APP_NAME}-${VERSION}-${VARIANT}"

    # Unmount any previously mounted volume with the same name
    hdiutil detach "/Volumes/${VOLNAME}" >/dev/null 2>&1 || true

    local TEMP_DIR="${DIST_DIR}/temp_dmg_${VARIANT}"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    cp -r "$APP_PATH" "$TEMP_DIR/"

    if command -v create-dmg &> /dev/null; then
        echo "Using create-dmg for styled ${VARIANT} DMG..."

        [ -f "$DMG_PATH" ] && rm "$DMG_PATH"

        create-dmg \
            --text-size 13 \
            --volname "${VOLNAME}" \
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
            hdiutil create -volname "${APP_NAME}-${VERSION}-${VARIANT}" \
                -srcfolder "$TEMP_DIR" \
                -ov -format UDZO "$DMG_PATH"
        }
    else
        echo "Using simple DMG mode..."
        ln -sf /Applications "$TEMP_DIR/Applications"
        hdiutil create -volname "${VOLNAME}" \
            -srcfolder "$TEMP_DIR" \
            -ov -format UDZO "$DMG_PATH"
    fi

    rm -rf "$TEMP_DIR"

    echo -e "${GREEN}${VARIANT} DMG: ${DMG_PATH}${NC}"
}

# Build only (no signing)
build_only() {
    build_all
    echo -e "${GREEN}Build complete${NC}"
    echo "  arm64-with-nodejs:  ${DIST_DIR}/${APP_NAME}-arm64-${WITH_NODE_SUFFIX}/${APP_BUNDLE}"
    echo "  x86_64-with-nodejs: ${DIST_DIR}/${APP_NAME}-x86_64-${WITH_NODE_SUFFIX}/${APP_BUNDLE}"
    echo "  universal-lite:     ${DIST_DIR}/${APP_NAME}-${UNIVERSAL_LITE_VARIANT}/${APP_BUNDLE}"
}

# Full release flow
release() {
    if check_signing_config; then
        build_all
        local variants=("arm64-${WITH_NODE_SUFFIX}" "x86_64-${WITH_NODE_SUFFIX}" "${UNIVERSAL_LITE_VARIANT}")
        for variant in "${variants[@]}"; do
            sign_app_variant "$variant"
            notarize_app_variant "$variant"
            create_dmg_variant "$variant"
        done
        echo -e "${GREEN}=== Release complete ===${NC}"
        echo "  arm64-with-nodejs DMG:  ${DIST_DIR}/${APP_NAME}-${VERSION}-arm64-${WITH_NODE_SUFFIX}.dmg"
        echo "  x86_64-with-nodejs DMG: ${DIST_DIR}/${APP_NAME}-${VERSION}-x86_64-${WITH_NODE_SUFFIX}.dmg"
        echo "  universal-lite DMG:     ${DIST_DIR}/${APP_NAME}-${VERSION}-${UNIVERSAL_LITE_VARIANT}.dmg"
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
        variants=("arm64-${WITH_NODE_SUFFIX}" "x86_64-${WITH_NODE_SUFFIX}" "${UNIVERSAL_LITE_VARIANT}")
        for variant in "${variants[@]}"; do
            sign_app_variant "$variant"
        done
        ;;
    dmg)
        variants=("arm64-${WITH_NODE_SUFFIX}" "x86_64-${WITH_NODE_SUFFIX}" "${UNIVERSAL_LITE_VARIANT}")
        for variant in "${variants[@]}"; do
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
