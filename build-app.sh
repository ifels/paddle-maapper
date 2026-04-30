#!/bin/bash
#
# PaddleMapper macOS App Build Script
# Compiles the Swift project and packages it into a .app bundle.
#
# Usage:
#   chmod +x build_app.sh
#   ./build_app.sh           # Release build (optimized, ~2min)
#   ./build_app.sh --fast    # Debug build (quick testing, ~15s)
#   ./build_app.sh --clean   # Full clean + Release build
#
# Output: build/PaddleMapper.app
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
BUILD_DIR="${PROJECT_DIR}/build"
SPM_BUILD_DIR="${PROJECT_DIR}/.build"

# Parse flags
DO_CLEAN=false
BUILD_CONFIG=release
for arg in "$@"; do
    case "$arg" in
        --fast)  BUILD_CONFIG=debug ;;
        --clean) DO_CLEAN=true ;;
    esac
done

APP_NAME="PaddleMapper"
BUNDLE_ID="com.ifels.controlflex.paddlemapper"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "=== PaddleMapper Build Script ==="
echo "Config:     ${BUILD_CONFIG}"
echo "Project:    ${PROJECT_DIR}"
echo "Output:     ${APP_BUNDLE}"
echo ""

# Step 1: Clean previous .app output only (keep SPM cache for incremental builds)
echo "[1/5] Cleaning previous app bundle..."
rm -rf "${BUILD_DIR}"
if [ "$DO_CLEAN" = true ]; then
    echo "  (full clean: removing .build cache)"
    rm -rf "${SPM_BUILD_DIR}"
fi

# Step 2: Build with Swift Package Manager
CONFIG_FLAG="-c ${BUILD_CONFIG}"
[ "$BUILD_CONFIG" = "release" ] && CONFIG_FLAG=""
echo "[2/5] Building with Swift Package Manager (${BUILD_CONFIG})..."
cd "${PROJECT_DIR}"
swift build -c "${BUILD_CONFIG}"
echo "  Build successful."

# Step 3: Find the compiled binary
if [ "$BUILD_CONFIG" = "release" ]; then
    BINARY_PATH="${SPM_BUILD_DIR}/apple/Products/Release/${APP_NAME}"
    [ ! -f "${BINARY_PATH}" ] && BINARY_PATH="${SPM_BUILD_DIR}/release/${APP_NAME}"
else
    BINARY_PATH="${SPM_BUILD_DIR}/debug/${APP_NAME}"
fi
if [ ! -f "${BINARY_PATH}" ]; then
    echo "ERROR: Compiled binary not found at ${BINARY_PATH}"
    exit 1
fi
echo "  Binary: ${BINARY_PATH}"

# Step 4: Create .app bundle structure
echo "[3/5] Creating .app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BINARY_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "${PROJECT_DIR}/App/entitlements.plist" "${APP_BUNDLE}/Contents/Resources/entitlements.plist"
# Copy app icon
if [ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi
# Copy setup-cert.sh into app bundle (for in-app certificate installation)
if [ -f "${PROJECT_DIR}/setup-cert.sh" ]; then
    cp "${PROJECT_DIR}/setup-cert.sh" "${APP_BUNDLE}/Contents/Resources/setup-cert.sh"
    chmod +x "${APP_BUNDLE}/Contents/Resources/setup-cert.sh"
fi
# Copy localization resources (.lproj directories)
for lproj_dir in "${PROJECT_DIR}/Resources/"*.lproj; do
    if [ -d "${lproj_dir}" ]; then
        lproj_name=$(basename "${lproj_dir}")
        cp -R "${lproj_dir}" "${APP_BUNDLE}/Contents/Resources/${lproj_name}"
    fi
done
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"
echo "  .app bundle created."

# Step 5: Code sign with stable certificate
CERT_IDENTITY="PaddleMapper Developer"
ENTITLEMENTS="${PROJECT_DIR}/App/entitlements.plist"

# Check if stable certificate is available
if security find-identity -v -p codesigning "${HOME}/Library/Keychains/login.keychain-db" 2>/dev/null | grep -q "${CERT_IDENTITY}"; then
    echo "[4/5] Code signing with certificate: ${CERT_IDENTITY}"

    # Sign with stable certificate (includes Hardened Runtime)
    if [ -f "${ENTITLEMENTS}" ]; then
        codesign --force --deep --sign "${CERT_IDENTITY}" \
                 --options runtime \
                 --entitlements "${ENTITLEMENTS}" \
                 "${APP_BUNDLE}" 2>/dev/null || {
            echo "  WARNING: Signing with Hardened Runtime failed, trying without --options runtime..."
            codesign --force --deep --sign "${CERT_IDENTITY}" \
                     --entitlements "${ENTITLEMENTS}" \
                     "${APP_BUNDLE}" 2>/dev/null || {
                echo "  WARNING: Certificate signing failed, falling back to ad-hoc..."
                codesign --force --deep --sign - --entitlements "${ENTITLEMENTS}" "${APP_BUNDLE}" 2>/dev/null || \
                    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
            }
        }
    else
        codesign --force --deep --sign "${CERT_IDENTITY}" \
                 --options runtime \
                 "${APP_BUNDLE}" 2>/dev/null || {
            codesign --force --deep --sign "${CERT_IDENTITY}" "${APP_BUNDLE}" 2>/dev/null || {
                codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
            }
        }
    fi

    # Verify signature
    if codesign --verify --deep --strict "${APP_BUNDLE}" 2>/dev/null; then
        echo "  ✅ Signature verified."
        codesign -d -r - "${APP_BUNDLE}" 2>/dev/null | head -1 | sed 's/^/  DR: /'
    else
        echo "  ⚠️  Signature verification failed."
    fi
else
    echo "[4/5] Code signing (ad-hoc — no stable certificate found)"
    echo "  ⚠️  Run ./setup-cert.sh to create a stable signing certificate."
    echo "     This avoids re-authorization after each build."
    if [ -f "${ENTITLEMENTS}" ]; then
        codesign --force --deep --sign - --entitlements "${ENTITLEMENTS}" "${APP_BUNDLE}" 2>/dev/null || {
            codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
        }
    else
        codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
    fi
fi
echo "  Signed."

# Done
echo ""
echo "[5/5] Build complete!"
echo ""
echo "  App: ${APP_BUNDLE}"
echo "  Size: $(du -sh "${APP_BUNDLE}" | cut -f1)"
echo ""
echo "To install:"
echo "  cp -r \"${APP_BUNDLE}\" /Applications/"
echo ""
echo "To run:"
echo "  open \"${APP_BUNDLE}\""
echo ""
echo "IMPORTANT: When you first run the app, you will be prompted to grant"
echo "Accessibility permission in System Settings > Privacy & Security > Accessibility."
echo "This is required for the app to simulate F-key presses."
