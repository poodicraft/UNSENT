#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# UNSENT (PC version) — one-time toolchain setup (Linux x86_64).
#
# Installs everything needed to export the Windows game headlessly:
#   * Godot 4.5.1 editor (headless-capable)           -> /opt/godot
#   * Godot 4.5.1 Windows + Linux export templates     -> ~/.local/share/godot/export_templates
#
# No Windows machine, Wine or rcedit is needed: Godot 4.5 writes the .exe's
# icon and version information itself.
#
# On Windows or macOS you can instead install Godot 4.5.1 and its export
# templates from https://godotengine.org/download and use the editor's
# Project → Export → "Windows Desktop".
# ---------------------------------------------------------------------------
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.5.1}"
GODOT_DIR="${GODOT_DIR:-/opt/godot}"
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

echo "==> Windows (and Linux, for testing) export templates"
if [ ! -f "$TPL_DIR/windows_release_x86_64.exe" ]; then
  mkdir -p "$TPL_DIR"
  curl -fL -o /tmp/templates.tpz "$REL/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  unzip -o -q -j /tmp/templates.tpz \
    templates/windows_release_x86_64.exe templates/windows_debug_x86_64.exe \
    templates/windows_release_x86_64_console.exe templates/windows_debug_x86_64_console.exe \
    templates/linux_release.x86_64 templates/linux_debug.x86_64 \
    templates/version.txt -d "$TPL_DIR"
  rm -f /tmp/templates.tpz
fi

if ! command -v zip >/dev/null; then
  echo "==> zip (for packaging)"
  sudo_cmd=""; [ "$(id -u)" -ne 0 ] && sudo_cmd="sudo"
  $sudo_cmd apt-get update -q && DEBIAN_FRONTEND=noninteractive $sudo_cmd apt-get install -y -q zip
fi

godot --version
echo "Toolchain ready. Build with: tools/build_windows.sh"
