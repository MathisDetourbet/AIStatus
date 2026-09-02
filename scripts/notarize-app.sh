#!/bin/bash
set -euo pipefail

# Submits a signed .app to Apple's notary service, staples the resulting ticket,
# and writes the stapled bundle to a distributable zip.
#
# The app must already be signed by scripts/sign-app.sh — notarization rejects
# anything without a Developer ID signature and the hardened runtime.
#
# Usage: NOTARY_APPLE_ID=... NOTARY_PASSWORD=... NOTARY_TEAM_ID=... \
#          ./scripts/notarize-app.sh build/AIStatusBar.app dist/AIStatusBar.zip

APP_PATH="${1:?Usage: $0 <path-to-.app> <output-zip>}"
OUTPUT_ZIP="${2:?Usage: $0 <path-to-.app> <output-zip>}"

: "${NOTARY_APPLE_ID:?NOTARY_APPLE_ID must be set}"
: "${NOTARY_PASSWORD:?NOTARY_PASSWORD must be set (an app-specific password)}"
: "${NOTARY_TEAM_ID:?NOTARY_TEAM_ID must be set}"

NOTARY_ARGS=(
    --apple-id "$NOTARY_APPLE_ID"
    --password "$NOTARY_PASSWORD"
    --team-id "$NOTARY_TEAM_ID"
)

# Notarization takes a zip, but the ticket is stapled to the .app itself, so this
# archive is throwaway — the release asset is re-zipped from the stapled bundle.
SUBMISSION_ZIP="$(mktemp -d)/$(basename "$APP_PATH").zip"
ditto -c -k --keepParent "$APP_PATH" "$SUBMISSION_ZIP"

echo "Submitting $(basename "$APP_PATH") to the notary service..."
RESULT=$(xcrun notarytool submit "$SUBMISSION_ZIP" "${NOTARY_ARGS[@]}" --wait --output-format json)
echo "$RESULT"

read_field() {
    echo "$RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['$1'])"
}
STATUS=$(read_field status)
SUBMISSION_ID=$(read_field id)

# notarytool exits 0 for a completed submission even when Apple rejected it, so
# the status has to be checked explicitly.
if [ "$STATUS" != "Accepted" ]; then
    echo "error: notarization failed with status '${STATUS}'. Full log:" >&2
    xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" >&2 || true
    exit 1
fi

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

# Gatekeeper's own verdict, as an end user's machine would render it.
spctl --assess --type execute --verbose=4 "$APP_PATH"

mkdir -p "$(dirname "$OUTPUT_ZIP")"
rm -f "$OUTPUT_ZIP"
ditto -c -k --keepParent "$APP_PATH" "$OUTPUT_ZIP"

echo "Notarized and stapled ${APP_PATH} -> ${OUTPUT_ZIP}"
