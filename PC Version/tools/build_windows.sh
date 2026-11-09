#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# UNSENT (PC version) — build the Windows game headlessly.
#
#   tools/build_windows.sh           -> build/UNSENT-Windows/UNSENT.exe   (release)
#                                       build/UNSENT-Windows.zip          (what players download)
#   tools/build_windows.sh --debug   -> build/UNSENT-Windows-debug/UNSENT.exe (+ console wrapper)
#
# The game is a single self-contained UNSENT.exe (the game data is embedded
# in it). It is 64-bit and runs on Windows 10 and 11 with any GPU that
# supports OpenGL 3.3 — or Direct3D 11, through the ANGLE fallback.
#
# The .exe is not code-signed, so Windows SmartScreen may say "Windows
# protected your PC" the first time: "More info" -> "Run anyway".
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

MODE="release"; NAME="UNSENT-Windows"
if [ "${1:-}" = "--debug" ]; then MODE="debug"; NAME="UNSENT-Windows-debug"; fi
OUT_DIR="$ROOT/build/$NAME"
EXE="$OUT_DIR/UNSENT.exe"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "==> Importing project resources"
"$GODOT" --headless --path "$ROOT" --import 2>&1 | grep -E "ERROR|SCRIPT ERROR" || true

echo "==> Exporting $MODE build -> $EXE"
LOG="$ROOT/build/export-windows.log"
set +e
"$GODOT" --headless --path "$ROOT" "--export-$MODE" "Windows Desktop" "$EXE" >"$LOG" 2>&1
STATUS=$?
set -e
grep -E "ERROR|WARNING|error" "$LOG" | tail -20 || true
if [ $STATUS -ne 0 ] || [ ! -s "$EXE" ]; then
  echo "!! Export failed (status $STATUS). Full log: $LOG"
  exit 1
fi

echo "==> Adding the read-me and licences"
cp "$ROOT/docs/README-Windows.txt" "$OUT_DIR/README.txt"
mkdir -p "$OUT_DIR/licenses"
cp "$ROOT"/assets/fonts/OFL-*.txt "$ROOT"/assets/fonts/LICENSE-*.txt "$OUT_DIR/licenses/"
cp "$ROOT/docs/GODOT-LICENSE.txt" "$OUT_DIR/licenses/Godot-Engine-and-third-party.txt"
# Windows-friendly line endings for the text files.
for f in "$OUT_DIR/README.txt" "$OUT_DIR"/licenses/*.txt; do
  sed -i 's/\r$//; s/$/\r/' "$f"
done

ls -l "$OUT_DIR"
if [ "$MODE" = "release" ]; then
  echo "==> Packaging $NAME.zip"
  rm -f "$ROOT/build/$NAME.zip"
  (cd "$ROOT/build" && zip -q -9 -r "$NAME.zip" "$NAME")
  ls -lh "$ROOT/build/$NAME.zip"
  (cd "$ROOT/build" && sha256sum "$NAME.zip" > "$NAME.zip.sha256" && cat "$NAME.zip.sha256")
fi
echo "==> Done: $EXE"
