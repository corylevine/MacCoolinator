#!/bin/bash
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="MacCoolinator"
APP_DIR="build/${APP_NAME}.app/Contents"

echo "Building ${APP_NAME} (${CONFIG})..."
swift build -c "$CONFIG"

echo "Assembling ${APP_NAME}.app..."
rm -rf "build/${APP_NAME}.app"
mkdir -p "${APP_DIR}/MacOS"
mkdir -p "${APP_DIR}/Resources"

cp ".build/${CONFIG}/${APP_NAME}" "${APP_DIR}/MacOS/${APP_NAME}"
cp "Sources/${APP_NAME}/Info.plist" "${APP_DIR}/Info.plist"

echo "Done → build/${APP_NAME}.app"
echo ""
echo "To install: cp -r build/${APP_NAME}.app /Applications/"
echo "To run:     open build/${APP_NAME}.app"
