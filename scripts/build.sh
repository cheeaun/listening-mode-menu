#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ROOT_DIR/.env"
  set +a
fi

APP_NAME="Listening Mode Menu"
EXECUTABLE_NAME="ListeningModeMenu"
BUNDLE_ID="cheeaun.ListeningModeMenu"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_SYSTEM_VERSION="14.0"
DIST_DIR="$ROOT_DIR/dist"
SWIFTPM_DIR="$ROOT_DIR/.build/swiftpm"
MODULE_CACHE_DIR="$ROOT_DIR/.build/module-cache"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
APP_ICON_SVG="$ROOT_DIR/assets/app-icon.svg"
APP_ICON_NAME="AppIcon"

export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"

usage() {
  cat <<USAGE
Usage: scripts/build.sh [command]

Commands:
  build       Build unsigned app bundle in dist/ (default)
  run         Build and launch the app
  debug       Build and launch under lldb
  logs        Build, launch, and stream app unified logs
  telemetry   Build, launch, and stream subsystem unified logs
  verify      Build, launch, and confirm the process is running
  sign        Build and sign with SIGN_IDENTITY
  dmg         Build a DMG. Signs first when SIGN_IDENTITY is set
  notarize    Sign app, create/sign DMG, submit for notarization, then staple
  clean       Remove build artifacts

Environment:
  SIGN_IDENTITY          Developer ID Application identity for distribution signing
  NOTARY_PROFILE         notarytool keychain profile name
  VERSION                App version, default 1.0.0
  BUILD_NUMBER           Bundle build number, default 1

The script also loads a local gitignored .env file before reading these values.
USAGE
}

command="${1:-build}"

build_binary() {
  mkdir -p "$SWIFTPM_DIR" "$MODULE_CACHE_DIR"
  swift build \
    --scratch-path "$SWIFTPM_DIR" \
    -Xcc -fmodules-cache-path="$MODULE_CACHE_DIR" \
    -Xswiftc -module-cache-path \
    -Xswiftc "$MODULE_CACHE_DIR" \
    -c release \
    --product "$EXECUTABLE_NAME" >&2
  swift build \
    --scratch-path "$SWIFTPM_DIR" \
    -Xcc -fmodules-cache-path="$MODULE_CACHE_DIR" \
    -Xswiftc -module-cache-path \
    -Xswiftc "$MODULE_CACHE_DIR" \
    -c release \
    --show-bin-path
}

write_info_plist() {
  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
}

generate_app_icon() {
  if [[ ! -f "$APP_ICON_SVG" ]]; then
    echo "Warning: $APP_ICON_SVG not found; building without app icon" >&2
    return 0
  fi
  if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "Warning: rsvg-convert not found; building without app icon (install librsvg: brew install librsvg)" >&2
    return 0
  fi

  local tmp_dir iconset_dir
  tmp_dir="$(mktemp -d)"
  iconset_dir="$tmp_dir/AppIcon.iconset"
  mkdir -p "$iconset_dir"

  rsvg-convert -w 16   -h 16   "$APP_ICON_SVG" -o "$iconset_dir/icon_16x16.png"
  rsvg-convert -w 32   -h 32   "$APP_ICON_SVG" -o "$iconset_dir/icon_16x16@2x.png"
  rsvg-convert -w 32   -h 32   "$APP_ICON_SVG" -o "$iconset_dir/icon_32x32.png"
  rsvg-convert -w 64   -h 64   "$APP_ICON_SVG" -o "$iconset_dir/icon_32x32@2x.png"
  rsvg-convert -w 128  -h 128  "$APP_ICON_SVG" -o "$iconset_dir/icon_128x128.png"
  rsvg-convert -w 256  -h 256  "$APP_ICON_SVG" -o "$iconset_dir/icon_128x128@2x.png"
  rsvg-convert -w 256  -h 256  "$APP_ICON_SVG" -o "$iconset_dir/icon_256x256.png"
  rsvg-convert -w 512  -h 512  "$APP_ICON_SVG" -o "$iconset_dir/icon_256x256@2x.png"
  rsvg-convert -w 512  -h 512  "$APP_ICON_SVG" -o "$iconset_dir/icon_512x512.png"
  rsvg-convert -w 1024 -h 1024 "$APP_ICON_SVG" -o "$iconset_dir/icon_512x512@2x.png"

  iconutil -c icns "$iconset_dir" -o "$RESOURCES_DIR/$APP_ICON_NAME.icns"
  rm -rf "$tmp_dir"
}

build_app() {
  local bin_dir
  bin_dir="$(build_binary)"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
  cp "$bin_dir/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
  chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"
  generate_app_icon
  write_info_plist
  if [[ -f "$RESOURCES_DIR/$APP_ICON_NAME.icns" ]]; then
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $APP_ICON_NAME" "$INFO_PLIST"
  fi
  plutil -lint "$INFO_PLIST"
  echo "Built $APP_BUNDLE"
}

sign_app() {
  : "${SIGN_IDENTITY:?SIGN_IDENTITY is required for signing}"
  build_app
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

create_dmg() {
  rm -f "$DMG_PATH"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_BUNDLE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
  echo "Created $DMG_PATH"
}

sign_dmg() {
  : "${SIGN_IDENTITY:?SIGN_IDENTITY is required for signing}"
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
}

notarize_app() {
  : "${SIGN_IDENTITY:?SIGN_IDENTITY is required for notarization}"
  : "${NOTARY_PROFILE:?NOTARY_PROFILE is required for notarization}"

  sign_app
  local notarization_zip="$DIST_DIR/$APP_NAME-$VERSION-notarization.zip"
  rm -f "$notarization_zip"
  ditto -c -k --keepParent "$APP_BUNDLE" "$notarization_zip"
  xcrun notarytool submit "$notarization_zip" --keychain-profile "$NOTARY_PROFILE" --wait
  rm -f "$notarization_zip"
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  spctl --assess --type execute --verbose "$APP_BUNDLE"
  create_dmg
  sign_dmg
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"
}

case "$command" in
  build)
    build_app
    ;;
  run)
    build_app
    pkill -f "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" >/dev/null 2>&1 || true
    /usr/bin/open -n "$APP_BUNDLE"
    ;;
  debug)
    build_app
    lldb -- "$MACOS_DIR/$EXECUTABLE_NAME"
    ;;
  logs)
    build_app
    pkill -f "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" >/dev/null 2>&1 || true
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "process == \"$EXECUTABLE_NAME\""
    ;;
  telemetry)
    build_app
    pkill -f "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" >/dev/null 2>&1 || true
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  verify)
    build_app
    pkill -f "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" >/dev/null 2>&1 || true
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 1
    pgrep -x "$EXECUTABLE_NAME" >/dev/null
    echo "Running: $EXECUTABLE_NAME"
    ;;
  sign)
    sign_app
    ;;
  dmg)
    if [[ -n "${SIGN_IDENTITY:-}" ]]; then
      sign_app
    else
      build_app
    fi
    create_dmg
    ;;
  notarize)
    notarize_app
    ;;
  clean)
    rm -rf "$DIST_DIR" "$ROOT_DIR/.build"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
