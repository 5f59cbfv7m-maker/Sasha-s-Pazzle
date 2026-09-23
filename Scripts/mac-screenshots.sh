#!/bin/zsh
# Mac App Store screenshots: a Debug build walked through the debug stages,
# each window captured at exactly the size App Store Connect accepts.
#
#   Scripts/mac-screenshots.sh [language] [window points]
#   Scripts/mac-screenshots.sh ru               # → docs/store/ru/Mac/, 2880×1800
#   Scripts/mac-screenshots.sh en 1280x800      # → 2560×1600, for a small screen
#
# Needs a Retina display (the capture is twice the window size in points) and,
# on the first run, Screen Recording permission for the terminal (System
# Settings › Privacy & Security). Stage runs keep their data in a scratch
# directory (`StageSandbox`), so your own saved games on this Mac are untouched.
set -euo pipefail
cd "$(dirname "$0")/.."

LANGUAGE=${1:-en}
WINDOW=${2:-1440x900}
OUT="docs/store/$LANGUAGE/Mac"
DD="${TMPDIR:-/tmp}/sashas-puzzles-mac-screenshots"
APP="$DD/Build/Products/Debug/Sasha's Puzzles.app"
# Same order rule as the phone: a board mid-solve first, then the library.
STAGES=(hint library completed huge dark scattered)
EXPECTED_WIDTH=$(( ${WINDOW%x*} * 2 ))
EXPECTED_HEIGHT=$(( ${WINDOW#*x} * 2 ))

xcodebuild -quiet -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$DD" build

window_id() {
  swift - <<'SWIFT'
import CoreGraphics
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []
if let window = windows.first(where: {
    $0[kCGWindowOwnerName as String] as? String == "Sasha's Puzzles" && $0[kCGWindowLayer as String] as? Int == 0
}) {
    print(window[kCGWindowNumber as String] as? Int ?? 0)
}
SWIFT
}

# Any running copy is quit first — including an installed one — otherwise the
# capture could find its window instead of the stage's.
quit_app() {
  pgrep -x "Sasha's Puzzles" >/dev/null || return 0
  osascript -e 'tell application id "com.kirillrychkov.SashasPazzle" to quit' >/dev/null 2>&1 || true
  for _ in {1..10}; do pgrep -x "Sasha's Puzzles" >/dev/null || return 0; sleep 0.5; done
}

# Cutting 800 pieces can take a while, so wait until two captures two seconds
# apart match (capped for screens that animate forever, like the confetti).
settle() {
  local previous="" current
  sleep 5
  for _ in {1..30}; do
    screencapture -x -o -l "$1" "$DD/probe.png"
    current=$(sips -Z 32 "$DD/probe.png" --out "$DD/probe-s.png" >/dev/null && md5 -q "$DD/probe-s.png")
    [[ "$current" == "$previous" ]] && return
    previous=$current
    sleep 2
  done
}

mkdir -p "$OUT"
rm -f "$OUT"/*.png
N=0
for STAGE in $STAGES; do
  N=$((N + 1))
  quit_app
  open -n "$APP" --args --stage "$STAGE" --clear-saves --window-size "$WINDOW" \
    -AppleLanguages "($LANGUAGE)" -onboarding YES -appearance light
  ID=""
  for _ in {1..20}; do
    sleep 1
    ID=$(window_id)
    [[ -n "$ID" && "$ID" != 0 ]] && break
  done
  [[ -n "$ID" && "$ID" != 0 ]] || { echo "The app window never appeared"; exit 1; }
  settle "$ID"
  FILE="$OUT/$N-$STAGE.png"
  screencapture -x -o -l "$ID" "$FILE"
  SIZE=$(sips -g pixelWidth -g pixelHeight "$FILE" | awk '/pixel/ {print $2}' | paste -sd x -)
  if [[ "$SIZE" != "${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}" ]]; then
    echo "$FILE is $SIZE, expected ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT} — is this a Retina display?"
  else
    echo "$FILE"
  fi
done
quit_app
