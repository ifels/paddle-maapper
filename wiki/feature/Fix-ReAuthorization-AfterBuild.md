# 修复：每次编译后需要重新授权

## 问题现象

每次执行 `./build_app.sh` 重新编译后，macOS 会再次弹出辅助功能（Accessibility）授权请求，
之前在「系统设置 → 隐私与安全性 → 辅助功能」中已授予的权限丢失，必须重新勾选。

## 根因分析

### 当前签名方式：Ad-hoc

```bash
# build_app.sh 第 90 行
codesign --force --deep --sign - --entitlements "${ENTITLEMENTS}" "${APP_BUNDLE}"
#                             ↑ ad-hoc 签名（减号）
```

`--sign -` 表示 **ad-hoc 签名**，它不会附加任何证书身份，仅对当前二进制内容生成签名。

### TCC 权限绑定机制

macOS TCC（Transparency, Consent, and Control）通过 **Designated Requirement (DR)** 来识别应用：

| 签名方式 | DR 内容 | 重新编译后 |
|----------|---------|-----------|
| Ad-hoc (`--sign -`) | `cdhash H<二进制哈希>` | DR 变化 → TCC 认为是新应用 → **权限重置** |
| 证书签名 (`--sign "证书名"`) | `identifier "bundle_id" and certificate leaf = H<证书公钥哈希>` | DR 不变 → TCC 认为是同一应用 → **权限保留** |

**结论**：ad-hoc 签名下，每次编译产生的二进制哈希不同 → DR 不同 → TCC 权限重置。
只要用同一个证书签名，DR 就会稳定（因为 `bundle_id` 和证书公钥哈希都不变），权限就不会丢。

---

## 修复方案：稳定自签证书签名链路

> 方案来源：方案 A —— 稳定自签证书 → 重构 build 脚本签名链路

### 核心思路

1. 创建一张 **长期有效的自签代码签名证书**（10 年有效期）
2. 将证书导入本地 Keychain 并设为信任
3. 所有构建统一使用该证书签名，确保 DR 稳定
4. **TCC 不区分自签证书和 Apple Developer ID 证书**，只要 DR 稳定就认可

### 为什么不用 Apple Developer ID？

| 对比项 | 自签证书 | Apple Developer ID |
|--------|---------|-------------------|
| 费用 | 免费 | $99/年 |
| CI 复杂度 | 低 | 需管理 provisioning profile |
| TCC 识别 | 只要 DR 稳定就认 | 同左 |
| 分发 | 仅限本机 | 可对外分发 |

本地开发场景下，自签证书完全够用。

---

## 实施步骤

### 第一步：创建 `setup-cert.sh` 证书管理脚本

在项目根目录创建 `setup-cert.sh`：

```bash
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

# 3. 打包成 PKCS#12 格式（必须加 -legacy 兼容 macOS security import）
openssl pkcs12 -export \
    -out "${P12_PATH}" \
    -inkey "${CERT_DIR}/private.key" \
    -in "${CERT_PATH}" \
    -password "pass:${P12_PASSWORD}" \
    -legacy

# 4. 确保 login keychain 已解锁
security unlock-keychain "${KEYCHAIN}" 2>/dev/null || true

# 5. 导入 PKCS#12 到 login keychain
security import "${P12_PATH}" \
    -k "${KEYCHAIN}" \
    -P "${P12_PASSWORD}" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

# 6. 设置证书为信任（macOS 15+ 必须使用 -d -r trustRoot，不带 -k 和 -p）
#    -d 表示添加到 admin 信任域；-r trustRoot 表示信任为根证书
#    需要管理员权限（sudo）
sudo security add-trusted-cert -d -r trustRoot "${CERT_PATH}"

# 7. 设置私钥 partition list（可选，避免 codesign 弹密码框）
#    如果 codesign 已能正常工作，此步骤可跳过
#    security set-key-partition-list -S apple-tool:,apple:,codesign: -k <login_password> "${KEYCHAIN}"

# 8. 清理临时文件（保留证书目录，方便后续重新导入）
rm -f "${CERT_DIR}/private.key" "${CERT_DIR}/cert.cfg"

echo ""
echo "✅ Certificate '${CERT_NAME}' installed successfully!"
echo "   Valid for: 10 years"
echo "   Keychain:  ${KEYCHAIN}"
echo ""
echo "   Next: run ./build_app.sh to build with stable signing."
```

### 第二步：修改 `build_app.sh` 签名逻辑

将原来的 ad-hoc 签名替换为证书签名。找到 `build_app.sh` 中的 **Step 5: Code sign** 部分，替换为：

```bash
# Step 5: Code sign with stable certificate
CERT_IDENTITY="PaddleMapper Developer"
ENTITLEMENTS="${PROJECT_DIR}/App/entitlements.plist"

echo "[4/5] Code signing..."

# 检查证书是否可用
if security find-identity -v -p codesigning "${HOME}/Library/Keychains/login.keychain-db" 2>/dev/null | grep -q "${CERT_IDENTITY}"; then
    echo "  Using certificate: ${CERT_IDENTITY}"

    # 使用稳定证书签名（含 Hardened Runtime）
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

    # 签名验证
    if codesign --verify --deep --strict "${APP_BUNDLE}" 2>/dev/null; then
        echo "  ✅ Signature verified."
        # 打印 Designated Requirement
        codesign -d -r - "${APP_BUNDLE}" 2>/dev/null | head -1 | sed 's/^/  DR: /'
    else
        echo "  ⚠️  Signature verification failed."
    fi
else
    echo "  ⚠️  Certificate '${CERT_IDENTITY}' not found, using ad-hoc signing."
    echo "     Run ./setup-cert.sh first to avoid re-authorization after each build."
    if [ -f "${ENTITLEMENTS}" ]; then
        codesign --force --deep --sign - --entitlements "${ENTITLEMENTS}" "${APP_BUNDLE}" 2>/dev/null || true
    else
        codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
    fi
fi
echo "  Signed."
```

### 第三步：首次安装证书

```bash
# 1. 创建并安装证书（只需执行一次）
chmod +x setup-cert.sh
./setup-cert.sh

# 2. 验证证书
./setup-cert.sh --verify

# 3. 正常构建（此后每次构建都会使用稳定证书签名）
./build_app.sh
```

---

## 关键技术细节

### 1. 证书参数说明

| 参数 | 值 | 说明 |
|------|-----|------|
| 密钥算法 | RSA 2048-bit | 满足代码签名要求 |
| 证书格式 | X.509 v3 | macOS 标准格式 |
| 扩展密钥用途 | `codeSigning` | 限定为代码签名用途 |
| 有效期 | 10 年 (3650 天) | 避免频繁更换 |
| 证书名称 | `PaddleMapper Developer` | build 脚本中引用此名称 |

### 2. Designated Requirement 对比

**Ad-hoc 签名**（当前）：
```
cdhash H"0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a90"
```
每次编译后 cdhash 必然变化 → TCC 权限重置。

**证书签名**（修复后，实测结果）：
```
identifier "com.ifels.controlflex.paddlemapper" and certificate root = H"1559fbe70c06ce221a5e532765e89b822b47c108"
```
`identifier` 由 Info.plist 的 `CFBundleIdentifier` 决定，`certificate root` 由证书公钥决定，
二者在重新编译后都不会变化 → TCC 权限保留。

### 3. 私钥 Partition List

`security set-key-partition-list -S apple-tool:,apple:,codesign:` 的作用：
- 允许 `codesign` 和 `security` 命令访问私钥而无需每次弹密码框
- 这里的 `codesign:` 标签专门为代码签名场景授权
- 首次执行时可能需要输入一次 Mac 登录密码并选择「始终允许」

### 4. Hardened Runtime

`--options runtime` 启用 Hardened Runtime：
- macOS 10.14.4+ 要求，用于通过 Gatekeeper
- 与 entitlements 配合使用，声明需要的系统权限例外
- 如果签名时未启用，某些 entitlements 可能不生效

### 5. `security add-trusted-cert` 的信任级别

> **实测发现（macOS 15 Sequoia）**：
> `security add-trusted-cert -r trustAsRoot -p codeSign -k "${KEYCHAIN}"` 在 macOS 15 上会报错
> `SecTrustSettingsSetTrustSettings: One or more parameters passed to a function were not valid.`
>
> **正确的命令**：`sudo security add-trusted-cert -d -r trustRoot cert.cer`
> - `-d` 表示添加到 admin 信任域
> - `-r trustRoot` 表示信任为根证书
> - **不带** `-k` 和 `-p` 标志
> - 需要 `sudo` 管理员权限

### 6. OpenSSL 3.x PKCS12 兼容性

> **实测发现**：macOS 的 `security import` 无法导入 OpenSSL 3.x 默认算法生成的 PKCS12 文件，
> 会报 `MAC verification failed during PKCS12 import`。
>
> **解决方案**：在 `openssl pkcs12 -export` 时加 `-legacy` 标志，使用 RC2/3DES 兼容算法。

---

## 验证清单

| 测试场景 | 预期结果 |
|---------|---------|
| 首次 `./setup-cert.sh` | 证书创建并安装成功，无报错 |
| `./setup-cert.sh --verify` | 输出 `✅ Certificate is available` |
| 首次 `./build_app.sh` | 使用证书签名，签名验证通过 |
| 首次运行 app | 授予辅助功能权限 |
| **第二次 `./build_app.sh` + 运行** | **不再需要重新授权** |
| 重启 Mac 后重新构建 | 权限仍在，无需重新授权 |
| `./setup-cert.sh --remove` | 证书从 Keychain 中移除 |

### 手动验证命令

```bash
# 查看当前可用的代码签名身份
security find-identity -v -p codesigning

# 查看应用的签名信息
codesign -dvvv build/PaddleMapper.app

# 查看应用的 Designated Requirement
codesign -d -r - build/PaddleMapper.app

# 验证签名
codesign --verify --deep --strict --verbose=4 build/PaddleMapper.app

# 查看 TCC 数据库中的授权记录
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
    "SELECT client, auth_value FROM access WHERE service='kTCCServiceAccessibility';"
```

---

## 常见问题

### Q1: `set-key-partition-list` 失败怎么办？

首次执行时可能弹出钥匙串密码框，请输入 Mac 登录密码并点击「始终允许」。
如果跳过了这一步，后续 `codesign` 可能每次都弹密码框，可以重新执行 `./setup-cert.sh`。

### Q2: 证书过期了怎么办？

证书有效期为 10 年。过期后：
```bash
./setup-cert.sh --remove    # 移除旧证书
./setup-cert.sh             # 创建新证书
```
注意：新证书的公钥哈希不同，DR 会变化，首次需要重新授权辅助功能。

### Q3: 多台 Mac 之间共享证书？

可以将 `~/.paddlemapper-cert/paddlemapper.p12` 复制到另一台 Mac，
然后手动 `security import` 导入。但不推荐在多台机器上使用同一张证书，
每台机器各自创建一张即可（TCC 是本机数据库，不跨机器同步）。

### Q4: 为什么不在系统 Keychain (`/Library/Keychains/System.keychain`) 中安装？

- 系统 Keychain 需要 `sudo` 权限
- 登录 Keychain 对当前用户已足够
- TCC 是按用户维度的，登录 Keychain 完全满足需求

### Q5: 如果还是被要求重新授权？

请确认：
1. `codesign -d -r - build/PaddleMapper.app` 输出的 DR 中包含 `certificate leaf`（而不是 `cdhash`）
2. `security find-identity -v -p codesigning` 中能看到 `PaddleMapper Developer`
3. 如果 TCC 缓存异常，可以尝试 `tccutil reset Accessibility` 重置后重新授权一次
