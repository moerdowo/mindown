#!/usr/bin/env bash
set -euo pipefail

# Build a release binary, download yt-dlp + a static ffmpeg, and bundle the
# whole lot into Mindown.app so end users get a fully self-contained download
# without having to install yt-dlp or ffmpeg separately.

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Mindown"
BUNDLE_ID="com.local.mindown"
APP_DIR="$ROOT/$APP_NAME.app"
BIN_CACHE="$ROOT/.bin-cache"

# Pinned upstream sources.
YTDLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
SITES_URL="https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/supportedsites.md"

ARCH="$(uname -m)"
case "$ARCH" in
    arm64)  FFMPEG_ASSET="ffmpeg-darwin-arm64" ;;
    x86_64) FFMPEG_ASSET="ffmpeg-darwin-x64"   ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
FFMPEG_VERSION="b6.1.1"
FFMPEG_URL="https://github.com/eugeneware/ffmpeg-static/releases/download/${FFMPEG_VERSION}/${FFMPEG_ASSET}"

mkdir -p "$BIN_CACHE"

fetch_if_missing() {
    local out="$1" url="$2" name="$3" mode="${4:-755}"
    if [[ -s "$out" ]]; then
        echo "==> Using cached $name ($(du -h "$out" | cut -f1))"
        return
    fi
    echo "==> Downloading $name from $url"
    curl --fail --location --progress-bar -o "$out.tmp" "$url"
    mv "$out.tmp" "$out"
    chmod "$mode" "$out"
}

fetch_if_missing "$BIN_CACHE/yt-dlp"            "$YTDLP_URL" "yt-dlp"                 755
fetch_if_missing "$BIN_CACHE/ffmpeg"            "$FFMPEG_URL" "ffmpeg ($FFMPEG_ASSET)" 755
fetch_if_missing "$BIN_CACHE/supportedsites.md" "$SITES_URL"  "supported sites list"  644

echo "==> Building release binary"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/Mindown"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "Could not find built binary at $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/bin"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

cp "$BIN_CACHE/yt-dlp"            "$APP_DIR/Contents/Resources/bin/yt-dlp"
cp "$BIN_CACHE/ffmpeg"            "$APP_DIR/Contents/Resources/bin/ffmpeg"
cp "$BIN_CACHE/supportedsites.md" "$APP_DIR/Contents/Resources/supportedsites.md"
chmod +x "$APP_DIR/Contents/Resources/bin/"*

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

# Ad-hoc sign the bundled binaries and the app itself. Apple Silicon refuses
# to execute unsigned binaries even from inside an unsigned bundle, so this
# step is required for the bundled yt-dlp/ffmpeg to launch on first run.
echo "==> Ad-hoc signing bundled binaries"
codesign --force --sign - "$APP_DIR/Contents/Resources/bin/yt-dlp"   2>/dev/null || true
codesign --force --sign - "$APP_DIR/Contents/Resources/bin/ffmpeg"   2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

# Strip any quarantine xattrs (no-op for locally produced files, but cheap insurance).
xattr -cr "$APP_DIR" 2>/dev/null || true

echo "==> Built $APP_DIR ($(du -sh "$APP_DIR" | cut -f1))"
echo "Run with: open \"$APP_DIR\""
