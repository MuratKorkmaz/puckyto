#!/bin/bash
# Wraps the swift build output into an .app bundle that carries Info.plist.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="Puckyto"
BUNDLE="build/${APP_NAME}.app"

echo "▸ swift build -c ${CONFIG}"
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all \
    swift build -c "${CONFIG}"

BIN=".build/${CONFIG}/Puckyto"

echo "▸ creating ${BUNDLE}"
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"
cp "${BIN}" "${BUNDLE}/Contents/MacOS/Puckyto"
cp Resources/Info.plist "${BUNDLE}/Contents/Info.plist"
cp Resources/AppIcon.icns "${BUNDLE}/Contents/Resources/AppIcon.icns"

echo "▸ signing (ad-hoc)"
codesign --force --sign - "${BUNDLE}"

echo "✅ Ready: ${BUNDLE}"
echo "   Run: open \"${BUNDLE}\""
