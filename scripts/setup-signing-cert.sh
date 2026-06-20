#!/bin/bash
# 在本机创建一个自签名「代码签名」证书并导入登录钥匙串。
# 目的：让 make-app.sh 用固定证书签名，App 的 designated requirement 绑定到证书，
# 这样每次重编重签后 macOS 仍认作同一 App，辅助功能 / 输入监控授权不会失效。
# 自签名证书完全免费、只存在于本机，不需要 Apple 开发者账号。
# 只需运行一次；之后日常 make-app.sh 会自动用它。
# 旧版脚本曾使用不安全的 security import -A；显式传入
# --rotate-insecure-existing 才会删除旧身份并创建安全的新身份。

set -euo pipefail

SIGN_ID="SafariGestures Self-Signed"
KEYCHAIN="${SAFARI_GESTURES_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
ROTATE=false

if [[ "${1:-}" == "--rotate-insecure-existing" ]]; then
  ROTATE=true
elif [[ $# -gt 0 ]]; then
  echo "用法：$0 [--rotate-insecure-existing]" >&2
  exit 64
fi

private_key_acl() (
  # awk 找到目标私钥块后提前结束；关闭这个子 shell 的 pipefail，避免上游
  # security 因管道关闭收到 SIGPIPE 后把“已找到”误判为失败。
  set +o pipefail
  security dump-keychain -a "$KEYCHAIN" 2>/dev/null | awk -v label="$SIGN_ID" '
    index($0, "0x00000001 <blob>=\"" label "\"") { found = 1 }
    found && /^keychain:/ { exit }
    found { print }
  '
)

has_broad_sign_acl() {
  private_key_acl | awk '
    /authorizations .*sign/ { sign_entry = 1; next }
    sign_entry && /applications: <null>/ { broad = 1; sign_entry = 0 }
    sign_entry && /applications/ { sign_entry = 0 }
    END { exit broad ? 0 : 1 }
  '
}

if security find-identity -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$SIGN_ID"; then
  if has_broad_sign_acl; then
    if [[ "$ROTATE" != true ]]; then
      echo "❌ 现有签名身份「${SIGN_ID}」使用旧版宽 ACL，任何应用都可免提示使用私钥。" >&2
      echo "   请在最终安装前运行：$0 --rotate-insecure-existing" >&2
      echo "   轮换后证书身份会改变，需要最后一次重新授予辅助功能权限。" >&2
      exit 2
    fi

    echo "将删除旧版宽 ACL 身份并创建安全的新身份；之后需要重新授予一次辅助功能权限。"
    security delete-identity -c "$SIGN_ID" "$KEYCHAIN"
  else
    echo "✅ 已存在签名身份「${SIGN_ID}」，未发现宽签名 ACL。"
    exit 0
  fi
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = SafariGestures Self-Signed
[ext]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# 生成自签名证书 + 私钥
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 3650 -config "$TMP/cert.cnf"

# 打包成 p12（必须 -legacy + 非空密码，否则 macOS security 报 MAC verification failed）
P12_PASSWORD="$(openssl rand -hex 16)"
openssl pkcs12 -export -legacy \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/cert.p12" -passout "pass:$P12_PASSWORD" -name "$SIGN_ID"

# -x：导入后私钥不可导出；-T：只允许系统 codesign 工具免提示使用。
# 禁止使用 -A，它会把签名私钥开放给任意应用。
security import "$TMP/cert.p12" -k "$KEYCHAIN" \
  -P "$P12_PASSWORD" -x -T /usr/bin/codesign

if has_broad_sign_acl; then
  echo "❌ 新身份仍出现宽签名 ACL，已停止。请删除该身份后检查钥匙串设置。" >&2
  exit 1
fi

# 用临时副本验证 codesign 确实能使用新私钥，不碰项目内的 App。
cp /usr/bin/true "$TMP/signing-smoke-test"
codesign --force --keychain "$KEYCHAIN" --sign "$SIGN_ID" "$TMP/signing-smoke-test"
codesign --verify --strict "$TMP/signing-smoke-test"

echo "✅ 已创建并导入签名身份「${SIGN_ID}」。现在可以跑 scripts/make-app.sh 用它签名。"
echo "   私钥不可导出，且未向任意应用开放签名权限。"
echo "   注意：自签名证书不被系统「信任」是正常的，不影响本机签名与授权稳定性。"
