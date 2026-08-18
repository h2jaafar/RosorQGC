#!/usr/bin/env bash
set -euo pipefail

LOG=/tmp/qgc_ekf_debug.log

if [ -d build/Release ] && [ -f build/Release/CMakeCache.txt ]; then
  BUILD_DIR=build/Release
  BIN=build/Release/QGroundControl
elif [ -d build ] && [ -f build/CMakeCache.txt ]; then
  BUILD_DIR=build
  if [ -x build/Release/QGroundControl ]; then
    BIN=build/Release/QGroundControl
  else
    BIN=build/qgroundcontrol
  fi
else
  echo "No configured build dir found. Run cmake -S . -B build -G Ninja first." >&2
  exit 1
fi

cmake --build "$BUILD_DIR"

if [ ! -x "$BIN" ]; then
  echo "Binary not found: $BIN" >&2
  exit 1
fi

rm -f "$LOG"

QT_QPA_PLATFORM=offscreen timeout -k 3 30s "$BIN" 2>&1 | tee "$LOG" || true

echo "---- EKF Debug Summary ----"
grep -n "RosorQGC EKF Snapshot" -n "$LOG" | tail -n 5 || true
grep -n "EkfStatusPopup computed" -n "$LOG" | tail -n 5 || true
grep -n "EkfStatusPopup created" -n "$LOG" | tail -n 3 || true

echo "---- Checks ----"
if ! grep -q "EKF source: ekfStatusReport" "$LOG"; then
  echo "FAIL: missing EKF source line" >&2
  exit 1
fi
if [ "$(grep -c "EkfStatusPopup computed" "$LOG")" -lt 3 ]; then
  echo "FAIL: missing computed lines" >&2
  exit 1
fi
if ! grep -q "flags: type=object" "$LOG"; then
  echo "FAIL: missing flags line" >&2
  exit 1
fi

echo "PASS"
