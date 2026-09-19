#!/usr/bin/env bash
# Create a self signed code signing identity in the login keychain.
#
# Why this exists: an ad hoc signature changes with every build, and macOS keys
# the Accessibility grant to the binary it saw. Signing with a stable identity
# instead means a rebuild keeps the permission the user already gave.
#
# Usage: bash scripts/make-signing-identity.sh ["Snap It Local Signing"]
set -euo pipefail

name="${1:-Snap It Local Signing}"

# find-identity only lists certificates trusted for code signing, and a self
# signed one is not; the certificate is still perfectly usable for signing, so
# look for the certificate itself.
if security find-certificate -c "$name" >/dev/null 2>&1; then
  echo "identity already exists: $name"
  echo "build with: make install SIGN_IDENTITY=\"$name\""
  exit 0
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cat > "$workdir/ext.cnf" <<CNF
[ req ]
distinguished_name = dn
prompt             = no
x509_extensions    = codesign

[ dn ]
CN = $name

[ codesign ]
basicConstraints       = critical,CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,codeSigning
subjectKeyIdentifier   = hash
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$workdir/key.pem" -out "$workdir/cert.pem" -config "$workdir/ext.cnf" 2>/dev/null

# -legacy keeps the PKCS12 MAC and ciphers at what the macOS keychain accepts;
# OpenSSL 3 defaults produce a bundle security(1) refuses to import.
openssl pkcs12 -export -legacy -inkey "$workdir/key.pem" -in "$workdir/cert.pem" \
  -name "$name" -out "$workdir/identity.p12" -passout pass:snapit 2>/dev/null

security import "$workdir/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
  -P snapit -T /usr/bin/codesign -A >/dev/null

# Let codesign use the key without a prompt on every build.
security set-key-partition-list -S apple-tool:,apple:,codesign: \
  -k "" "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1 || true

echo "created identity: $name"
echo "build with: make install SIGN_IDENTITY=\"$name\""
