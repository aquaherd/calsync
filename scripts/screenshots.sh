#!/usr/bin/env bash
# Captures the App Store screenshots of CalSync from the iOS Simulator.
#
# The app seeds demo calendars, events and syncs through the DEBUG-only launch
# argument --seed-demo, so the screenshots show real rows and real results.
# Output: docs/app-store/screenshots/<de|en>/<iphone-6.9|ipad-13>/*.png
set -euo pipefail

cd "$(dirname "$0")/.."

# Keep Apple's tools first, matching scripts/testflight.sh.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

PROJECT="CalSync.xcodeproj"
SCHEME="CalSync"
BUNDLE_ID="de.erduman.calsync"
RUNTIME="iOS 26.4"
DERIVED_PATH="build/screenshots"
APP_PATH="$DERIVED_PATH/Build/Products/Debug-iphonesimulator/CalSync.app"
OUTPUT_ROOT="docs/app-store/screenshots"

fail() {
  echo "error: $*" >&2
  exit 1
}

udid_for() {
  xcrun simctl list devices "$RUNTIME" \
    | grep -F "    $1 (" \
    | head -n 1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

assert_dimensions() {
  local png="$1"
  local expected_width="$2"
  local expected_height="$3"
  local width height

  [[ -f "$png" ]] || fail "screenshot missing: $png"

  width="$(sips -g pixelWidth "$png" | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$png" | awk '/pixelHeight/ {print $2}')"

  [[ "$width" == "$expected_width" && "$height" == "$expected_height" ]] \
    || fail "$png is ${width}x${height}, expected ${expected_width}x${expected_height}"
}

assert_no_alpha() {
  local png="$1"
  local alpha

  alpha="$(sips -g hasAlpha "$png" | awk '/hasAlpha/ {print $2}')"
  [[ "$alpha" == "no" ]] || fail "$png still has an alpha channel"
}

# Overwrites the PNG through JPEG at quality 100 to drop the alpha channel.
# App Store Connect rejects screenshots with transparency.
flatten() {
  local png="$1"
  local jpeg="${png%.png}.flatten.jpg"

  sips -s format jpeg -s formatOptions 100 "$png" --out "$jpeg" >/dev/null
  sips -s format png "$jpeg" --out "$png" >/dev/null
  rm -f "$jpeg"
}

capture() {
  local udid="$1"
  local path="$2"
  local launch_args="$3"
  local wait_seconds="$4"
  local expected_width="$5"
  local expected_height="$6"

  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  # shellcheck disable=SC2086
  xcrun simctl launch "$udid" "$BUNDLE_ID" $launch_args
  sleep "$wait_seconds"
  mkdir -p "$(dirname "$path")"
  xcrun simctl io "$udid" screenshot --type=png "$path"
  # iOS shows one-time system banners (such as "Ready for Apple Intelligence")
  # shortly after the first launch on a fresh simulator. Take the shot again at
  # least 10 seconds later so a late banner is gone from the final image.
  sleep 12
  xcrun simctl io "$udid" screenshot --type=png "$path"
  assert_dimensions "$path" "$expected_width" "$expected_height"
}

echo "==> Building $SCHEME"
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_PATH" \
  CODE_SIGNING_ALLOWED=NO

[[ -d "$APP_PATH" ]] || fail "built app not found at $APP_PATH"

# A complete run replaces every screenshot, so stale images cannot survive.
find "$OUTPUT_ROOT" -name '*.png' -delete 2>/dev/null || true

for lang in de en; do
  if [[ "$lang" == "de" ]]; then
    locale="de_DE"
  else
    locale="en_US"
  fi

  for device in "iPhone 17 Pro Max|1320|2868|iphone-6.9" "iPad Pro 13-inch (M5)|2064|2752|ipad-13"; do
    IFS='|' read -r device_name width height folder <<< "$device"
    udid="$(udid_for "$device_name")"
    [[ -n "$udid" ]] || fail "$device_name not found in runtime $RUNTIME"

    echo "==> $lang: $device_name ($udid)"

    # A fresh data container keeps the demo seed and permission grant deterministic.
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    xcrun simctl erase "$udid"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b

    # The language switch is only picked up after a restart.
    xcrun simctl spawn "$udid" defaults write NSGlobalDomain AppleLanguages -array "$lang"
    xcrun simctl spawn "$udid" defaults write NSGlobalDomain AppleLocale -string "$locale"
    xcrun simctl shutdown "$udid"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b

    # The one-time "Ready for Apple Intelligence" banner appears a few seconds
    # after SpringBoard is ready and stays up for a while. Wait it out before
    # installing and launching, otherwise it lands in the screenshot.
    sleep 45

    # A language switch that was lost (for example because another run rebooted
    # the same simulator) would silently produce the wrong localization.
    applied_languages="$(xcrun simctl spawn "$udid" defaults read NSGlobalDomain AppleLanguages 2>/dev/null || true)"
    applied_locale="$(xcrun simctl spawn "$udid" defaults read NSGlobalDomain AppleLocale 2>/dev/null || true)"
    [[ "$applied_languages" == *"$lang"* ]] \
      || fail "$device_name did not switch to $lang (AppleLanguages: $applied_languages)"
    [[ "$applied_locale" == *"$locale"* ]] \
      || fail "$device_name did not switch to $locale (AppleLocale: $applied_locale)"

    xcrun simctl status_bar "$udid" override \
      --time "9:41" \
      --batteryState charged \
      --batteryLevel 100 \
      --dataNetwork wifi \
      --wifiMode active \
      --wifiBars 3 \
      --cellularMode active \
      --cellularBars 4

    xcrun simctl install "$udid" "$APP_PATH"
    xcrun simctl privacy "$udid" grant calendar "$BUNDLE_ID"

    if [[ "$device_name" == iPhone* ]]; then
      capture "$udid" "$OUTPUT_ROOT/$lang/$folder/01-syncs.png" \
        "--seed-demo" 10 "$width" "$height"
      capture "$udid" "$OUTPUT_ROOT/$lang/$folder/02-sync-editor.png" \
        "--seed-demo --demo-open-editor" 5 "$width" "$height"
    else
      capture "$udid" "$OUTPUT_ROOT/$lang/$folder/01-workspace.png" \
        "--seed-demo" 10 "$width" "$height"
      capture "$udid" "$OUTPUT_ROOT/$lang/$folder/02-new-sync.png" \
        "--seed-demo --demo-new-sync" 5 "$width" "$height"
    fi

    xcrun simctl status_bar "$udid" clear
  done
done

echo "==> Flattening and checking screenshots"
count=0
while IFS= read -r file; do
  case "$file" in
    */iphone-6.9/*) expected_width=1320; expected_height=2868 ;;
    */ipad-13/*) expected_width=2064; expected_height=2752 ;;
    *) fail "unexpected screenshot path: $file" ;;
  esac

  flatten "$file"
  assert_dimensions "$file" "$expected_width" "$expected_height"
  assert_no_alpha "$file"

  count=$((count + 1))
  echo
  echo "$file"
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$file"
  ls -lh "$file"
done < <(find "$OUTPUT_ROOT" -name '*.png' | sort)

[[ "$count" -eq 8 ]] || fail "expected 8 screenshots, found $count"
