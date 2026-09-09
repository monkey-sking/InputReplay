#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "InputReplay local doctor"
echo "========================"

echo
echo "[macOS]"
sw_vers || true

echo
echo "[Xcode]"
if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -version
else
  echo "xcodebuild: missing"
fi

echo
echo "[Swift]"
if command -v swift >/dev/null 2>&1; then
  swift --version
else
  echo "swift: missing"
fi

echo
echo "[Git]"
git status --short --branch || true

echo
echo "[Signing identities]"
if command -v security >/dev/null 2>&1; then
  security find-identity -v -p codesigning || true
fi

echo
echo "[Current Accessibility database note]"
echo "InputReplay cannot inspect TCC grants from this script."
echo "After launching the app, verify System Settings > Privacy & Security > Accessibility."

echo
echo "[Build prerequisites]"
FAILED=0
for cmd in swift codesign ditto plutil; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK  $cmd=$(command -v "$cmd")"
  else
    echo "MISS $cmd"
    FAILED=1
  fi
done

if [[ "$FAILED" == "1" ]]; then
  echo
echo "Doctor found missing prerequisites."
  exit 1
fi

echo
echo "Environment looks ready for an InputReplay development build."
