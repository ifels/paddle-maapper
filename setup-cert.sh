#!/bin/bash
#
# PaddleMapper 自签代码签名证书管理脚本
#
# 用法:
#   ./setup-cert.sh              # 创建并安装证书
#   ./setup-cert.sh --remove     # 移除证书
#   ./setup-cert.sh --verify     # 验证证书是否可用
#
set -euo pipefail

CERT_NAME="PaddleMapper Developer"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
CERT_DIR="${HOME}/.paddlemapper-cert"
CERT_PATH="${CERT_DIR}/paddlemapper.cer"
P12_PATH="${CERT_DIR}/paddlemapper.p12"
P12_PASSWORD="paddlemapper"

# ─── 移除证书 ───
if [[ "${1:-}" == "--remove" ]]; then
    echo "Removing certificate '${CERT_NAME}'..."
    security delete-certificate -c "${CERT_NAME}" 2>/dev/null || true
    rm -rf "${CERT_DIR}"
    echo "Done."
    exit 0
fi

# ─── 验证证书 ───
if [[ "${1:-}" == "--verify" ]]; then
    if security find-identity -v -p codesigning "${KEYCHAIN}" 2>/dev/null | grep -q "${CERT_NAME}"; then
        echo "✅ Certificate '${CERT_NAME}' is available for codesigning."
        exit 0
    else
        echo "❌ Certificate '${CERT_NAME}' NOT found or not trusted for codesigning."
        echo "   Run: ./setup-cert.sh"
        exit 1
    fi
fi

# ─── 创建证书 ───
echo "=== PaddleMapper Certificate Setup ==="

# 检查是否已存在
if security find-identity -v -p codesigning "${KEYCHAIN}" 2>/dev/null | grep -q "${CERT_NAME}"; then
    echo "✅ Certificate '${CERT_NAME}' already exists. No action needed."
    exit 0
fi

echo "Creating self-signed code signing certificate..."

mkdir -p "${CERT_DIR}"

# 1. 生成 OpenSSL 配置
cat > "${CERT_DIR}/cert.cfg" <<'EOF'
[ req ]
default_bits       = 2048
default_md         = sha256
prompt             = no
distinguished_name = dn
x509_extensions    = v3_code

[ dn ]
CN = PaddleMapper Developer
O  = PaddleMapper
C  = CN

[ v3_code ]
basicConstraints    = critical, CA:FALSE
keyUsage            = critical, digitalSignature
extendedKeyUsage    = critical, codeSigning
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer
EOF

# 2. 生成私钥 + 证书（10 年有效期）
openssl req -x509 \
    -newkey rsa:2048 \
    -keyout "${CERT_DIR}/private.key" \
    -out "${CERT_PATH}" \
    -days 3650 \
    -nodes \
    -config "${CERT_DIR}/cert.cfg"

# 3. 打包成 PKCS#12 格式（使用 -legacy 兼容 macOS security import）
openssl pkcs12 -export \
    -out "${P12_PATH}" \
    -inkey "${CERT_DIR}/private.key" \
    -in "${CERT_PATH}" \
    -password "pass:${P12_PASSWORD}" \
    -legacy 2>/dev/null || \
openssl pkcs12 -export \
    -out "${P12_PATH}" \
    -inkey "${CERT_DIR}/private.key" \
    -in "${CERT_PATH}" \
    -password "pass:${P12_PASSWORD}" \
    -certpbe PBE-SHA1-RC2-40 -keypbe PBE-SHA1-3DES

# 4. 确保 login keychain 已解锁
security unlock-keychain "${KEYCHAIN}" 2>/dev/null || true

# 5. 导入 PKCS#12 到 login keychain
security import "${P12_PATH}" \
    -k "${KEYCHAIN}" \
    -P "${P12_PASSWORD}" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

# 6. 设置证书为信任（macOS 15+ 需要管理员权限）
#    -d 表示添加到 admin 信任域；-r trustRoot 表示信任为根证书
#    不带 -k 和 -p 标志（在 macOS 15 上这些标志会导致参数错误）
security add-trusted-cert -d -r trustRoot "${CERT_PATH}" 2>/dev/null || {
    echo "  ⚠️  add-trusted-cert 需要管理员权限，尝试 sudo..."
    echo "  （请输入你的 Mac 管理员密码）"
    sudo security add-trusted-cert -d -r trustRoot "${CERT_PATH}" 2>/dev/null || {
        echo "  ❌ add-trusted-cert 失败。证书已导入但未被信任，codesign 可能不可用。"
        echo "     请手动执行: sudo security add-trusted-cert -d -r trustRoot ${CERT_PATH}"
    }
}

# 7. 设置私钥 partition list（允许 codesign 免密访问私钥）
#    注意：-k 需要输入 login keychain 的密码，此处通过交互方式处理
#    如果 codesign 已能正常使用，此步骤可跳过
security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -k "" \
    "${KEYCHAIN}" 2>/dev/null || {
    echo ""
    echo "  ℹ️  如需设置私钥 partition list（避免 codesign 弹密码框），请手动执行："
    echo "     security set-key-partition-list -S apple-tool:,apple:,codesign: -k <your_login_password> \"${KEYCHAIN}\""
    echo "     （如果 codesign 已能正常工作，可以忽略此提示）"
}

# 8. 清理临时文件（保留证书目录，方便后续重新导入）
rm -f "${CERT_DIR}/private.key" "${CERT_DIR}/cert.cfg"

echo ""
echo "✅ Certificate '${CERT_NAME}' installed successfully!"
echo "   Valid for: 10 years"
echo "   Keychain:  ${KEYCHAIN}"
echo ""
echo "   Next: run ./build-app.sh to build with stable signing."
