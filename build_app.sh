#!/bin/bash

# DuoduoManager build script
# Supports universal binary build, code signing, notarization, and DMG packaging

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
BUILD_DIR=".build/release"
DIST_DIR="dist"

echo -e "${GREEN}=== DuoduoManager Build ===${NC}"
echo "Version: ${VERSION}"

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

# Build universal binary
build_universal() {
    echo -e "${GREEN}Building universal binary...${NC}"

    rm -rf "${DIST_DIR}"
    mkdir -p "${DIST_DIR}"

    echo "Building arm64..."
    swift build -c release --arch arm64

    echo "Building x86_64..."
    swift build -c release --arch x86_64

    UNIVERSAL_DIR="${DIST_DIR}/universal"
    mkdir -p "${UNIVERSAL_DIR}/bin"

    echo "Creating universal binary..."
    ARM64_BIN=".build/arm64-apple-macosx/release/${APP_NAME}"
    X86_64_BIN=".build/x86_64-apple-macosx/release/${APP_NAME}"

    if [ -f "$ARM64_BIN" ] && [ -f "$X86_64_BIN" ]; then
        lipo -create "$ARM64_BIN" "$X86_64_BIN" -output "${UNIVERSAL_DIR}/bin/${APP_NAME}"
        echo -e "${GREEN}Universal binary created${NC}"
    else
        echo -e "${RED}Build artifacts not found${NC}"
        exit 1
    fi
}

# Create App Bundle
create_app_bundle() {
    echo -e "${GREEN}Creating App Bundle...${NC}"

    APP_PATH="${DIST_DIR}/${APP_BUNDLE}"

    cp -r "${TEMPLATE_DIR}" "${APP_PATH}"
    cp "${DIST_DIR}/universal/bin/${APP_NAME}" "${APP_PATH}/Contents/MacOS/"
    chmod +x "${APP_PATH}/Contents/MacOS/${APP_NAME}"
    echo -n "APPL????" > "${APP_PATH}/Contents/PkgInfo"

    # Copy localization resources
    mkdir -p "${APP_PATH}/Contents/Resources"
    cp -r Sources/Resources/*.lproj "${APP_PATH}/Contents/Resources/"

    echo -e "${GREEN}App Bundle created: ${APP_PATH}${NC}"
}

# Sign app
sign_app() {
    echo -e "${GREEN}Signing application...${NC}"

    APP_PATH="${DIST_DIR}/${APP_BUNDLE}"

    xattr -cr "$APP_PATH"

    codesign --force --options runtime \
        --sign "${APPLE_TEAM_NAME}" \
        --entitlements "entitlements.mac.plist" \
        --deep "$APP_PATH"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Signing succeeded${NC}"
    else
        echo -e "${RED}Signing failed${NC}"
        exit 1
    fi
}

# Notarize app
notarize_app() {
    echo -e "${GREEN}Notarizing application...${NC}"

    APP_PATH="${DIST_DIR}/${APP_BUNDLE}"
    ZIP_PATH="${DIST_DIR}/${APP_NAME}.zip"

    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

    echo "Submitting notarization request (may take a few minutes)..."
    xcrun notarytool submit "$ZIP_PATH" \
        --wait \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
        --team-id "${APPLE_TEAM_ID}"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Notarization succeeded${NC}"
        xcrun stapler staple "$APP_PATH"
        echo -e "${GREEN}Notarization staple attached${NC}"
    else
        echo -e "${RED}Notarization failed${NC}"
        exit 1
    fi

    rm "$ZIP_PATH"
}

# Create DMG
create_dmg() {
    echo -e "${GREEN}Creating DMG...${NC}"

    APP_PATH="${DIST_DIR}/${APP_BUNDLE}"
    DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

    TEMP_DIR="${DIST_DIR}/temp_dmg"
    mkdir -p "$TEMP_DIR"
    cp -r "$APP_PATH" "$TEMP_DIR/"

    if command -v create-dmg &> /dev/null; then
        echo "Using create-dmg for styled DMG..."

        [ -f "$DMG_PATH" ] && rm "$DMG_PATH"

        create-dmg \
            --text-size 13 \
            --volname "${APP_NAME}-${VERSION}" \
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
            hdiutil create -volname "${APP_NAME}-${VERSION}" \
                -srcfolder "$TEMP_DIR" \
                -ov -format UDZO "$DMG_PATH"
        }
    else
        echo "Using simple DMG mode..."
        ln -sf /Applications "$TEMP_DIR/Applications"
        hdiutil create -volname "${APP_NAME}-${VERSION}" \
            -srcfolder "$TEMP_DIR" \
            -ov -format UDZO "$DMG_PATH"
    fi

    rm -rf "$TEMP_DIR"

    echo -e "${GREEN}DMG created: ${DMG_PATH}${NC}"
}

# Build only (no signing)
build_only() {
    build_universal
    create_app_bundle
    echo -e "${GREEN}Build complete: ${DIST_DIR}/${APP_BUNDLE}${NC}"
}

# Full release flow
release() {
    if check_signing_config; then
        build_universal
        create_app_bundle
        sign_app
        notarize_app
        create_dmg
        echo -e "${GREEN}=== Release complete ===${NC}"
        echo "DMG: ${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
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
    echo "  build     - Build only, create App Bundle (no signing)"
    echo "  release   - Full release flow (build + sign + notarize + DMG)"
    echo "  sign      - Sign existing App Bundle only"
    echo "  dmg       - Create DMG only"
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
        sign_app
        ;;
    dmg)
        create_dmg
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
