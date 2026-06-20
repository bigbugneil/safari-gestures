#!/bin/bash
# 在本机创建一个自签名「代码签名」证书并导入登录钥匙串。
# 目的：让 make-app.sh 用固定证书签名，App 的 designated requirement 绑定到证书，
# 这样每次重编重签后 macOS 仍认作同一 App，辅助功能 / 输入监控授权不会失效。
# 自签名证书完全免费、只存在于本机，不需要 Apple 开发者账号。
# 只需运行一次；之后日常 make-app.sh 会自动用它。

set -euo pipefail

SIGN_ID="SafariGestures Self-Signed"

if security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
  echo "✅ 已存在签名身份「$SIGN_ID」，无需重复创建。"
  exit 0
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
openssl pkcs12 -export -legacy \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/cert.p12" -passout pass:sgtemp -name "$SIGN_ID"

# 导入登录钥匙串；-A 允许 codesign 免提示使用私钥
security import "$TMP/cert.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
  -P "sgtemp" -A -T /usr/bin/codesign

echo "✅ 已创建并导入签名身份「$SIGN_ID」。现在可以跑 scripts/make-app.sh 用它签名。"
echo "   注意：自签名证书不被系统「信任」是正常的，不影响本机签名与授权稳定性。"
