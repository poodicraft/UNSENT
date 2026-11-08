#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# UNSENT — one-time toolchain setup (Linux x86_64).
#
# Installs everything needed to export the Android APK headlessly:
#   * Godot 4.5.1 editor (headless-capable)            -> /opt/godot
#   * Godot 4.5.1 Android export templates              -> ~/.local/share/godot/export_templates
#   * apksigner / adb / zipalign (Debian/Ubuntu pkgs)   -> /usr/bin
#   * a minimal Android SDK layout Godot accepts        -> /opt/android-sdk
#
# A full Android SDK is NOT required: UNSENT uses Godot's prebuilt-template
# export path (no Gradle build), which only needs apksigner for signing.
# If you already have a real Android SDK, just set ANDROID_HOME to it.
# ---------------------------------------------------------------------------
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.5.1}"
GODOT_DIR="${GODOT_DIR:-/opt/godot}"
SDK_DIR="${ANDROID_HOME:-/opt/android-sdk}"
REL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"

echo "==> Godot ${GODOT_VERSION} editor"
mkdir -p "$GODOT_DIR"
if [ ! -x "$GODOT_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64" ]; then
  curl -fL -o /tmp/godot.zip "$REL/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  unzip -o -q /tmp/godot.zip -d "$GODOT_DIR"
  rm -f /tmp/godot.zip
fi
ln -sf "$GODOT_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot

echo "==> Android export templates"
if [ ! -f "$TPL_DIR/android_release.apk" ]; then
  mkdir -p "$TPL_DIR"
  curl -fL -o /tmp/templates.tpz "$REL/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  unzip -o -q -j /tmp/templates.tpz \
    templates/android_debug.apk templates/android_release.apk templates/version.txt -d "$TPL_DIR"
  rm -f /tmp/templates.tpz
fi

echo "==> apksigner / adb / zipalign"
if ! command -v apksigner >/dev/null; then
  sudo_cmd=""; [ "$(id -u)" -ne 0 ] && sudo_cmd="sudo"
  $sudo_cmd apt-get update -q
  DEBIAN_FRONTEND=noninteractive $sudo_cmd apt-get install -y -q apksigner adb zipalign aapt
fi

echo "==> Minimal Android SDK layout at $SDK_DIR"
if [ ! -e "$SDK_DIR/build-tools" ]; then
  mkdir -p "$SDK_DIR/platform-tools" "$SDK_DIR/build-tools/35.0.0"
  ln -sf "$(command -v adb)" "$SDK_DIR/platform-tools/adb"
  ln -sf "$(command -v apksigner)" "$SDK_DIR/build-tools/35.0.0/apksigner"
  ln -sf "$(command -v zipalign)" "$SDK_DIR/build-tools/35.0.0/zipalign"
fi

godot --version
echo "Toolchain ready. Build with: tools/build_apk.sh"
