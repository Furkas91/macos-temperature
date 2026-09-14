#!/usr/bin/env bash
# Build TemperatureBar.app
# Works around broken CLT Swift Package Manager / SDK mismatch on some macOS installs
# by compiling with swiftc against a patched SDK copy + VFS overlay.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="TemperatureBar"
BUILD="$ROOT/.build"
OUT="$BUILD/manual"
SDK_SRC="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
# Prefer the concrete 26.2 SDK if present (symlink target of MacOSX.sdk may vary)
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.2.sdk ]]; then
  SDK_SRC="/Library/Developer/CommandLineTools/SDKs/MacOSX26.2.sdk"
fi
SDK="$BUILD/MacOSX.sdk"
SRC="$ROOT/Sources/TemperatureBar"
APP_DIR="$ROOT/dist/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"

mkdir -p "$OUT" "$BUILD/overlays"

# --- Patched SDK (compiler version must match installed swiftc) ---
COMPILER_TAG="$(swiftc -print-target-info | python3 -c 'import sys,json; print(json.load(sys.stdin)["swiftCompilerTag"])')"
# e.g. swiftlang-6.2.3.3.21
NEED_PATCH=0
if [[ ! -d "$SDK" ]]; then
  NEED_PATCH=1
elif ! grep -q "$COMPILER_TAG" "$SDK/usr/lib/swift/CoreFoundation.swiftmodule/arm64e-apple-macos.swiftinterface" 2>/dev/null; then
  NEED_PATCH=1
fi

if [[ "$NEED_PATCH" -eq 1 ]]; then
  echo "Preparing patched SDK for $COMPILER_TAG…"
  rm -rf "$SDK"
  cp -Rc "$SDK_SRC" "$SDK"
  # Rewrite interface compiler tags to match the installed toolchain
  SHORT_VER="$(swiftc -version 2>&1 | sed -n 's/.*Swift version \([0-9.]*\).*/\1/p' | head -1)"
  find "$SDK" -name '*.swiftinterface' -print0 | xargs -0 perl -pi -e \
    "s/swiftlang-[0-9.]+/${COMPILER_TAG}/g; s/Apple Swift version [0-9.]+ /Apple Swift version ${SHORT_VER} /g"
fi

# --- Fix duplicate SwiftBridging module map via VFS overlay ---
: > "$BUILD/overlays/empty.modulemap"
cat > "$BUILD/overlays/swiftbridging.yaml" <<EOF
version: 0
case-sensitive: false
roots:
  - name: "/Library/Developer/CommandLineTools/usr/include/swift"
    type: directory
    contents:
      - name: "module.modulemap"
        type: file
        external-contents: "$BUILD/overlays/empty.modulemap"
EOF

echo "Compiling ${APP_NAME}…"
swiftc -parse-as-library \
  -O \
  -sdk "$SDK" \
  -target arm64-apple-macos14.0 \
  -vfsoverlay "$BUILD/overlays/swiftbridging.yaml" \
  -framework SwiftUI -framework AppKit -framework Charts -framework IOKit \
  "$SRC/ThermalReader.swift" \
  "$SRC/TemperatureStore.swift" \
  "$SRC/PopoverView.swift" \
  "$SRC/TemperatureBarApp.swift" \
  -o "$OUT/$APP_NAME"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SRC/Info.plist" 2>/dev/null || echo "1.0")"
DMG_NAME="${APP_NAME}-${VERSION}"
DMG_PATH="$ROOT/dist/${DMG_NAME}.dmg"
STAGE="$BUILD/dmg-stage"

echo "Assembling ${APP_NAME}.app…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$CONTENTS/Resources"
cp "$OUT/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$SRC/Info.plist" "$CONTENTS/Info.plist"
cp "$SRC/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
printf 'APPL????' > "$CONTENTS/PkgInfo"
chmod +x "$MACOS_DIR/$APP_NAME"
xattr -cr "$APP_DIR" 2>/dev/null || true

echo "Creating ${DMG_NAME}.dmg…"
rm -rf "$STAGE" "$DMG_PATH"
mkdir -p "$STAGE"
cp -R "$APP_DIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# Read-only compressed DMG with drag-to-Applications layout
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$STAGE"

echo "Done:"
echo "  App: $APP_DIR"
echo "  DMG: $DMG_PATH"
echo "Install: open \"$DMG_PATH\"  →  drag TemperatureBar into Applications"
