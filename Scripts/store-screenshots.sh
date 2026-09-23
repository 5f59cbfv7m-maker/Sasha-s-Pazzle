#!/bin/zsh
# App Store screenshots: a Debug build on the two simulators App Store Connect
# requires (iPhone 6.9" and iPad 13"), walked through the debug stages.
#
#   Scripts/store-screenshots.sh [language]      # default en → docs/store/en/
#
# Output is exactly the pixel size App Store Connect expects (1320×2868 and
# 2064×2752). Landscape iPad frames come from --tray-trailing, which forces the
# landscape layout; rotate them 90° before uploading if you want true landscape.
set -euo pipefail
cd "$(dirname "$0")/.."

LANGUAGE=${1:-en}
OUT="docs/store/$LANGUAGE"
DD="${TMPDIR:-/tmp}/sashas-puzzles-screenshots"
BUNDLE=com.kirillrychkov.SashasPazzle
typeset -A LOCALES=(en en_US ru ru_RU de de_DE fr fr_FR es es_ES it it_IT pt-BR pt_BR ja ja_JP ko ko_KR zh-Hans zh_CN)
LOCALE=${LOCALES[$LANGUAGE]:-en_US}
# Upload order: the first three show in search results, so a board mid-solve
# leads. Files are numbered so Finder sorts them the way they go in; `board`
# (an empty table under the faint guide) is left out on purpose.
STAGES=(hint library completed scattered dark settings)

# Cutting a big puzzle on a freshly booted simulator can outlast any fixed
# sleep, so wait until two thumbnails two seconds apart match (capped for
# screens that animate forever, like the confetti).
settle() {
  local previous="" current
  sleep 4
  for _ in {1..10}; do
    xcrun simctl io "$1" screenshot "$DD/probe.png" >/dev/null 2>&1
    current=$(sips -Z 16 "$DD/probe.png" --out "$DD/probe-s.png" >/dev/null && md5 -q "$DD/probe-s.png")
    [[ "$current" == "$previous" ]] && return
    previous=$current
    sleep 2
  done
}

for DEVICE in "iPhone 17 Pro Max" "iPad Pro 13-inch (M5)"; do
  UDID=$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  [[ -n "$UDID" ]] || { echo "No simulator named '$DEVICE' — add it in Xcode › Settings › Components"; exit 1; }
  # The iPad status bar shows the date in the simulator's own language, so the
  # simulator is switched to the screenshot language (and restored at the end).
  PREVIOUS_LANGUAGES=$(xcrun simctl spawn "$UDID" defaults read -g AppleLanguages 2>/dev/null | tr -d ' \n()"' || true)
  PREVIOUS_LOCALE=$(xcrun simctl spawn "$UDID" defaults read -g AppleLocale 2>/dev/null || true)
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  if [[ "$(xcrun simctl spawn "$UDID" defaults read -g AppleLocale 2>/dev/null)" != "$LOCALE" ]]; then
    xcrun simctl spawn "$UDID" defaults write -g AppleLanguages -array "$LANGUAGE"
    xcrun simctl spawn "$UDID" defaults write -g AppleLocale "$LOCALE"
    xcrun simctl shutdown "$UDID"
    xcrun simctl boot "$UDID"
    xcrun simctl bootstatus "$UDID" -b >/dev/null
  fi
  xcodebuild -quiet -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -configuration Debug \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DD" build
  xcrun simctl install "$UDID" "$DD/Build/Products/Debug-iphonesimulator/Sasha's Puzzles.app"
  # The classic 9:41 status bar; the date's language follows the simulator's
  # own setting, not -AppleLanguages.
  xcrun simctl status_bar "$UDID" override --time 9:41 --batteryLevel 100 --wifiBars 3 --cellularBars 4 >/dev/null

  DIR="$OUT/${DEVICE// /-}"
  mkdir -p "$DIR"
  rm -f "$DIR"/*.png
  N=0
  for STAGE in $STAGES; do
    N=$((N + 1))
    xcrun simctl terminate "$UDID" $BUNDLE 2>/dev/null || true
    xcrun simctl launch "$UDID" $BUNDLE --stage "$STAGE" --clear-saves \
      -AppleLanguages "($LANGUAGE)" -onboarding YES -appearance light >/dev/null
    settle "$UDID"
    xcrun simctl io "$UDID" screenshot "$DIR/$N-$STAGE.png" >/dev/null 2>&1
    echo "$DIR/$N-$STAGE.png"
  done
  xcrun simctl status_bar "$UDID" clear >/dev/null
  if [[ -n "$PREVIOUS_LOCALE" && "$PREVIOUS_LOCALE" != "$LOCALE" && -z "${KEEP_SIM_LANGUAGE:-}" ]]; then
    xcrun simctl spawn "$UDID" defaults write -g AppleLanguages -array ${(s:,:)PREVIOUS_LANGUAGES}
    xcrun simctl spawn "$UDID" defaults write -g AppleLocale "$PREVIOUS_LOCALE"
    xcrun simctl shutdown "$UDID"
  fi
done
