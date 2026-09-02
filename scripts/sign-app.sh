#!/bin/bash
set -euo pipefail

# Code-signs an .app bundle with a Developer ID Application certificate and the
# hardened runtime, which notarization requires.
#
# Usage: MACOS_SIGNING_IDENTITY="Developer ID Application: Name (TEAMID)" \
#          ./scripts/sign-app.sh build/AIStatusBar.app

APP_PATH="${1:?Usage: $0 <path-to-.app>}"
IDENTITY="${MACOS_SIGNING_IDENTITY:?MACOS_SIGNING_IDENTITY must be set, e.g. \"Developer ID Application: Name (TEAMID)\"}"

if [ ! -d "$APP_PATH" ]; then
    echo "error: $APP_PATH does not exist. Run scripts/bundle-app.sh first." >&2
    exit 1
fi

SIGN_ARGS=(--force --options runtime --timestamp --sign "$IDENTITY")

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
