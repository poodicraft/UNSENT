#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# UNSENT — build the Android APK headlessly.
#
#   tools/build_apk.sh            -> build/UNSENT.apk (release build, signed)
#   tools/build_apk.sh --debug    -> build/UNSENT-debug.apk (debuggable build)
#
# Signing: by default the APK is signed with the bundled development key
# (android/keystore/unsent-dev.keystore, alias "unsent", password "unsent-dev").
# That key is public — fine for sideloading, NOT for store publication.
# To sign with your own key, export before running:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"

KS="$ROOT/android/keystore/unsent-dev.keystore"
if [ ! -f "$KS" ]; then
  echo "==> Generating development keystore"
  mkdir -p "$(dirname "$KS")"
  keytool -genkeypair -keystore "$KS" -storepass unsent-dev -alias unsent \
    -keypass unsent-dev -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=UNSENT Development, O=Hushwater Post Office, C=US"
fi
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$KS}"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-unsent}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-unsent-dev}"
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$KS}"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-unsent}"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-unsent-dev}"

MODE="release"; OUT="$ROOT/build/UNSENT.apk"
if [ "${1:-}" = "--debug" ]; then MODE="debug"; OUT="$ROOT/build/UNSENT-debug.apk"; fi
mkdir -p "$ROOT/build"
rm -f "$OUT" "$OUT.idsig"

echo "==> Importing project resources"
"$GODOT" --headless --path "$ROOT" --import 2>&1 | grep -v -E "JAVA_TOOL_OPTIONS|^\s*$" || true

echo "==> Exporting $MODE APK -> $OUT"
LOG="$ROOT/build/export.log"
set +e
"$GODOT" --headless --path "$ROOT" "--export-$MODE" "Android" "$OUT" >"$LOG" 2>&1
STATUS=$?
set -e
grep -E "ERROR|error|Signed|DONE" "$LOG" | grep -v JAVA_TOOL | tail -20 || true
rm -f "$OUT.idsig"

if [ $STATUS -ne 0 ] || [ ! -s "$OUT" ]; then
  echo "!! Export failed (status $STATUS). Full log: $LOG"
  exit 1
fi

echo "==> Verifying APK"
apksigner verify --verbose "$OUT" 2>&1 | grep -v JAVA_TOOL | head -6
if command -v aapt >/dev/null; then
  aapt dump badging "$OUT" 2>/dev/null | grep -E "^package|sdkVersion|targetSdk|uses-permission|native-code|launchable" || true
fi
ls -lh "$OUT"
echo "==> Done: $OUT"
