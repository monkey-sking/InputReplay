#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

bash scripts/doctor.sh

echo
echo "Running unit tests..."
swift test

echo
echo "Packaging development app..."
bash scripts/package-app.sh

echo
echo "Development app is ready:"
echo "  $ROOT_DIR/dist/InputReplay.app"
echo
echo "To launch:"
echo "  open \"$ROOT_DIR/dist/InputReplay.app\""

echo
echo "First real-Mac smoke test:"
echo "  1. Grant Accessibility permission to this packaged InputReplay.app."
echo "  2. Open TextEdit and select ABC."
echo "  3. Type: ceshiyixia"
echo "  4. Switch to Apple Pinyin."
echo "  5. Press Control + Option + R once for the safety notice, then again for replay."
echo "  6. The original text must remain untouched."

if [[ "${OPEN_APP:-0}" == "1" ]]; then
  open "$ROOT_DIR/dist/InputReplay.app"
fi
