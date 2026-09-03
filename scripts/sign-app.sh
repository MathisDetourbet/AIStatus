#!/bin/bash
set -euo pipefail

# Code-signs an .app bundle with a Developer ID Application certificate and the
# hardened runtime, which notarization requires.
#
# The identity is discovered from the keychain by default. Set
# MACOS_SIGNING_IDENTITY to override, and MACOS_KEYCHAIN to search a specific
# keychain instead of the default search list.
#
# Usage: ./scripts/sign-app.sh build/AIStatusBar.app

APP_PATH="${1:?Usage: $0 <path-to-.app>}"
KEYCHAIN="${MACOS_KEYCHAIN:-}"

if [ ! -d "$APP_PATH" ]; then
    echo "error: $APP_PATH does not exist. Run scripts/bundle-app.sh first." >&2
    exit 1
fi

FIND_ARGS=(-v -p codesigning)
[ -n "$KEYCHAIN" ] && FIND_ARGS+=("$KEYCHAIN")

# Matching on the certificate's common name is brittle — a stray quote or a
# trailing newline in a CI secret yields codesign's opaque "no identity found".
# Resolve the identity to its SHA-1 hash instead, which codesign also accepts.
IDENTITY="${MACOS_SIGNING_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    MATCHES=$(security find-identity "${FIND_ARGS[@]}" | grep "Developer ID Application" || true)
    COUNT=$(printf '%s\n' "$MATCHES" | grep -c . || true)

    if [ "$COUNT" -eq 0 ]; then
        echo "error: no Developer ID Application identity found in the keychain." >&2
        echo "       An Apple Development certificate cannot be notarized." >&2
        exit 1
    fi
    if [ "$COUNT" -gt 1 ]; then
        echo "error: $COUNT Developer ID Application identities found; set MACOS_SIGNING_IDENTITY to pick one:" >&2
        printf '%s\n' "$MATCHES" >&2
        exit 1
    fi

    IDENTITY=$(printf '%s\n' "$MATCHES" | awk '{print $2}')
    echo "Using identity:$(printf '%s\n' "$MATCHES" | sed 's/^ *[0-9]*)[^"]*//')"
fi

SIGN_ARGS=(--force --options runtime --timestamp --sign "$IDENTITY")
[ -n "$KEYCHAIN" ] && SIGN_ARGS+=(--keychain "$KEYCHAIN")

# Universal builds (.build/apple/Products/Release) emit proper bundles with an
# Info.plist, which codesign signs happily. Single-arch builds emit resource
# bundles as flat directories with no Info.plist and no binary — codesign
# rejects those, and they need no signature of their own since the app's
# signature seals them as resources.
is_signable() {
    [ -f "$1/Contents/Info.plist" ] && return 0
    find "$1" -type f -exec file -b {} + 2>/dev/null | grep -q "Mach-O"
}

# codesign works inside-out: nested code must be signed before the outer bundle,
# otherwise sealing the app invalidates the nested signatures.
while IFS= read -r -d '' nested; do
    if ! is_signable "$nested"; then
        echo "Skipping flat resource bundle: ${nested#"$APP_PATH"/}"
        continue
    fi
    echo "Signing nested code: ${nested#"$APP_PATH"/}"
    codesign "${SIGN_ARGS[@]}" "$nested"
done < <(find "$APP_PATH/Contents" \
    \( -name "*.bundle" -o -name "*.framework" -o -name "*.dylib" \) -print0)

echo "Signing app: $APP_PATH"
codesign "${SIGN_ARGS[@]}" "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --display --verbose=4 "$APP_PATH" 2>&1 | grep -E "^(Identifier|Authority|TeamIdentifier|Timestamp)"

echo "Signed ${APP_PATH}"
