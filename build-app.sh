#!/bin/bash
#
# PaddleMapper macOS App Build Script
# 编译 Swift 工程 → 打包 .app → 代码签名 → 生成 .dmg 安装包
#
# 最低系统版本: macOS 12.0 (Monterey)
#
# 用法:
#   ./build-app.sh              # Release 构建 (优化, 推荐)
#   ./build-app.sh --fast       # Debug 构建 (快速验证)
#   ./build-app.sh --clean      # 先清理构建缓存, 再 Release 构建
#   ./build-app.sh --universal  # 通用二进制 (Intel + Apple Silicon)
#   ./build-app.sh --no-dmg     # 只生成 .app, 不生成 .dmg
#
# 产物:
#   build/PaddleMapper.app
#   build/PaddleMapper-<版本>.dmg
#
# 注意: 本机 Command Line Tools 的 SwiftPM 不可用 (manifest 编译报
#       "no such module 'PackageDescription'"), 因此脚本直接用 swiftc
#       编译 Sources 下的所有 Swift 文件, 不依赖 swift build。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
BUILD_DIR="${PROJECT_DIR}/build"
SOURCES_DIR="${PROJECT_DIR}/Sources"

MIN_MACOS="12.0"
APP_NAME="PaddleMapper"
BUNDLE_ID="com.ifels.controlflex.paddlemapper"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
ENTITLEMENTS="${PROJECT_DIR}/App/entitlements.plist"
CERT_IDENTITY="PaddleMapper Developer"

# ─── 解析参数 ───
DO_CLEAN=false
DO_DMG=true
DO_UNIVERSAL=false
OPT_FLAGS=(-O)
for arg in "$@"; do
    case "$arg" in
        --fast)      OPT_FLAGS=(-Onone -g) ;;
        --clean)     DO_CLEAN=true ;;
        --no-dmg)    DO_DMG=false ;;
        --universal) DO_UNIVERSAL=true ;;
        -h|--help)   sed -n '2,25p' "$0"; exit 0 ;;
    esac
done

APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "${PROJECT_DIR}/Resources/Info.plist" 2>/dev/null || echo "1.0.0")
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${APP_VERSION}.dmg"

echo "=== PaddleMapper Build Script ==="
echo "Version:     ${APP_VERSION}"
echo "Min macOS:   ${MIN_MACOS}"
echo "Optimize:    ${OPT_FLAGS[*]}"
echo "Universal:   ${DO_UNIVERSAL}"
echo "Project:     ${PROJECT_DIR}"
echo "Output:      ${APP_BUNDLE}"
echo ""

# ─── 0. 环境检查 ───
if ! command -v swiftc >/dev/null 2>&1; then
    echo "ERROR: 未找到 swiftc, 请先安装 Xcode Command Line Tools:"
    echo "       xcode-select --install"
    exit 1
fi
SDK_PATH="$(xcrun --show-sdk-path)"
HOST_ARCH="$(uname -m)"

# ─── 1. 清理 ───
echo "[1/6] 清理旧的构建产物..."
rm -rf "${BUILD_DIR}"
if [ "$DO_CLEAN" = true ]; then
    echo "      (--clean: 同时清理 .build 缓存)"
    rm -rf "${PROJECT_DIR}/.build"
fi
mkdir -p "${BUILD_DIR}"

# ─── 2. 编译 ───
echo "[2/6] 编译 (target: macos${MIN_MACOS})..."
SWIFT_SOURCES=()
while IFS= read -r file; do
    SWIFT_SOURCES+=("$file")
done < <(find "${SOURCES_DIR}" -name '*.swift' | sort)

if [ ${#SWIFT_SOURCES[@]} -eq 0 ]; then
    echo "ERROR: ${SOURCES_DIR} 下没有找到 Swift 源文件"
    exit 1
fi

compile_arch() {
    local arch="$1"
    local output="$2"
    swiftc \
        "${OPT_FLAGS[@]}" \
        -target "${arch}-apple-macos${MIN_MACOS}" \
        -sdk "${SDK_PATH}" \
        -module-name "${APP_NAME}" \
        -framework IOKit \
        -o "${output}" \
        "${SWIFT_SOURCES[@]}"
}

if [ "$DO_UNIVERSAL" = true ]; then
    RAW_BINARY_DIR="${BUILD_DIR}/.binaries"
    mkdir -p "${RAW_BINARY_DIR}"
    for arch in x86_64 arm64; do
        echo "      → 编译 ${arch} ..."
        compile_arch "${arch}" "${RAW_BINARY_DIR}/${APP_NAME}-${arch}"
    done
    lipo -create \
        "${RAW_BINARY_DIR}/${APP_NAME}-x86_64" \
        "${RAW_BINARY_DIR}/${APP_NAME}-arm64" \
        -output "${RAW_BINARY_DIR}/${APP_NAME}"
    BINARY_PATH="${RAW_BINARY_DIR}/${APP_NAME}"
else
    BINARY_PATH="${BUILD_DIR}/${APP_NAME}"
    compile_arch "${HOST_ARCH}" "${BINARY_PATH}"
fi
echo "      编译成功 ($(lipo -info "${BINARY_PATH}" | sed 's/.*architecture[s]*: //'))"

# ─── 3. 组装 .app ───
echo "[3/6] 组装 .app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"

cp "${BINARY_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
if [ -f "${ENTITLEMENTS}" ]; then
    cp "${ENTITLEMENTS}" "${APP_BUNDLE}/Contents/Resources/entitlements.plist"
fi
if [ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# 证书安装脚本 (App 内 「安装证书」 按钮会调用)
if [ -f "${PROJECT_DIR}/setup-cert.sh" ]; then
    cp "${PROJECT_DIR}/setup-cert.sh" "${APP_BUNDLE}/Contents/Resources/setup-cert.sh"
    chmod +x "${APP_BUNDLE}/Contents/Resources/setup-cert.sh"
fi

# 本地化资源
for lproj_dir in "${PROJECT_DIR}/Resources/"*.lproj; do
    if [ -d "${lproj_dir}" ]; then
        cp -R "${lproj_dir}" "${APP_BUNDLE}/Contents/Resources/$(basename "${lproj_dir}")"
    fi
done

printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

# 清理中间产物
rm -rf "${BUILD_DIR}/.binaries"
[ "$DO_UNIVERSAL" = false ] && rm -f "${BINARY_PATH}"
echo "      .app 组装完成。"

# ─── 4. 代码签名 ───
echo "[4/6] 代码签名..."
SIGN_ARGS=(--force --sign - --timestamp=none)
[ -f "${ENTITLEMENTS}" ] && SIGN_ARGS+=(--entitlements "${ENTITLEMENTS}")

if security find-identity -v -p codesigning "${HOME}/Library/Keychains/login.keychain-db" 2>/dev/null \
        | grep -q "${CERT_IDENTITY}"; then
    echo "      使用稳定证书: ${CERT_IDENTITY}"
    SIGN_ARGS=(--force --sign "${CERT_IDENTITY}" --timestamp=none)
    [ -f "${ENTITLEMENTS}" ] && SIGN_ARGS+=(--entitlements "${ENTITLEMENTS}")
    if ! codesign "${SIGN_ARGS[@]}" "${APP_BUNDLE}" 2>/dev/null; then
        echo "      证书签名失败 (带 hardened runtime 选项), 重试..."
        codesign "${SIGN_ARGS[@]}" "${APP_BUNDLE}"
    fi
else
    echo "      ⚠️  未找到证书「${CERT_IDENTITY}」, 使用 ad-hoc 签名"
    echo "         提示: 运行 ./setup-cert.sh 生成稳定证书, 可避免每次编译后重新授权辅助功能。"
    codesign "${SIGN_ARGS[@]}" "${APP_BUNDLE}"
fi

if codesign --verify --strict "${APP_BUNDLE}" 2>/dev/null; then
    echo "      ✅ 签名校验通过"
else
    echo "      ⚠️  签名校验未通过 (不影响本机运行)"
fi

# ─── 5. 生成 DMG 安装包 ───
if [ "$DO_DMG" = true ]; then
    echo "[5/6] 生成 DMG 安装包..."
    STAGING_DIR="${BUILD_DIR}/.dmg-staging"
    rm -rf "${STAGING_DIR}"
    mkdir -p "${STAGING_DIR}"
    cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"
    ln -s /Applications "${STAGING_DIR}/Applications"

    hdiutil create \
        -volname "${APP_NAME}" \
        -srcfolder "${STAGING_DIR}" \
        -ov -format UDZO \
        "${DMG_PATH}" >/dev/null
    rm -rf "${STAGING_DIR}"
    echo "      DMG 生成完成。"
else
    echo "[5/6] 跳过 DMG (--no-dmg)。"
fi

# ─── 6. 完成 ───
echo ""
echo "[6/6] 构建完成！"
echo ""
echo "  App:  ${APP_BUNDLE}"
echo "  大小: $(du -sh "${APP_BUNDLE}" | cut -f1)"
if [ "$DO_DMG" = true ]; then
    echo "  安装包: ${DMG_PATH} ($(du -sh "${DMG_PATH}" | cut -f1))"
fi
echo ""
echo "安装方式:"
if [ "$DO_DMG" = true ]; then
    echo "  open \"${DMG_PATH}\"      # 打开安装包, 把 PaddleMapper 拖到 Applications"
fi
echo "  或: cp -r \"${APP_BUNDLE}\" /Applications/"
echo ""
echo "运行: open \"/Applications/${APP_NAME}.app\"  (状态栏会出现手柄图标)"
echo ""
echo "首次运行提示:"
echo "  1. 系统会要求授予「辅助功能」权限: 系统偏好设置 → 安全性与隐私 → 隐私 → 辅助功能"
echo "  2. 已开启「开机启动」时, 登录后仅驻留菜单栏, 不弹出主窗口"
