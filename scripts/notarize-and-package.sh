#!/bin/bash
# Archives, exports, notarizes, staples, and packages a macOS app into a DMG.
# Signing material comes from the environment/keychain; nothing is read from the repo.
#
# Required env:
#   APPLE_API_KEY_ID, APPLE_API_ISSUER_ID, APPLE_API_KEY_PATH  - notarization credentials
#   VERSION                                                     - marketing version (no leading v)
# Optional env:
#   APP_NAME      - scheme/product name        (default: flick)
#   PROJECT_PATH  - path to .xcodeproj         (default: flick.xcodeproj)
set -euo pipefail

: "${APPLE_API_KEY_ID:?Missing APPLE_API_KEY_ID}"
: "${APPLE_API_ISSUER_ID:?Missing APPLE_API_ISSUER_ID}"
: "${APPLE_API_KEY_PATH:?Missing APPLE_API_KEY_PATH}"
VERSION="${VERSION:?Missing VERSION}"
VERSION="${VERSION#v}"

APP_NAME="${APP_NAME:-flick}"
PROJECT_PATH="${PROJECT_PATH:-flick.xcodeproj}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${RUNNER_TEMP:-$ROOT_DIR/build}/release-${GITHUB_RUN_ID:-local}"
TEAM_ID="72CW7UW6RB"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archive"
# Signing settings are forced here so per-project pbxproj state can't produce
# an unsigned or debug-entitled build. archive (never plain build) is required:
# plain builds embed get-task-allow and skip the secure timestamp, which
# notarization rejects.
xcodebuild \
  -project "$ROOT_DIR/$PROJECT_PATH" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
  MARKETING_VERSION="$VERSION" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  ENABLE_HARDENED_RUNTIME=YES \
  ONLY_ACTIVE_ARCH=NO \
  archive

echo "==> Export Developer ID app"
xcodebuild -exportArchive \
  -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
  -exportPath "$BUILD_DIR/export" \
  -exportOptionsPlist "$ROOT_DIR/scripts/ExportOptions.plist"

APP_PATH="$BUILD_DIR/export/$APP_NAME.app"
test -d "$APP_PATH"

echo "==> Notarize app"
ditto -c -k --keepParent "$APP_PATH" "$BUILD_DIR/$APP_NAME.zip"
xcrun notarytool submit "$BUILD_DIR/$APP_NAME.zip" \
  --key "$APPLE_API_KEY_PATH" \
  --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER_ID" \
  --wait

echo "==> Staple and assess app"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

echo "==> Package and notarize DMG"
STAGING_DIR="$BUILD_DIR/dmg-staging"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

DMG_PATH="$BUILD_DIR/$APP_NAME-${VERSION}-macos.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" \
  --key "$APPLE_API_KEY_PATH" \
  --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER_ID" \
  --wait
# NOTE: do not spctl-assess the DMG itself; hdiutil DMGs are unsigned by design
# and always fail that check. stapler validate is the correct verification.
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

mkdir -p "$ROOT_DIR/dist"
cp "$DMG_PATH" "$ROOT_DIR/dist/"
shasum -a 256 "$ROOT_DIR/dist/$(basename "$DMG_PATH")" \
  > "$ROOT_DIR/dist/$(basename "$DMG_PATH").sha256"

echo "==> Done: dist/$(basename "$DMG_PATH")"
