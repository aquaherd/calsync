#!/usr/bin/env bash
# Archives CalSync and uploads it to App Store Connect / TestFlight.
#
# Authentication (pick one):
#   - Sign in to your Apple ID in Xcode › Settings › Accounts, or
#   - Use an App Store Connect API key (recommended for CI):
#       export ASC_KEY_ID=XXXXXXXXXX
#       export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#       export ASC_KEY_PATH=~/private_keys/AuthKey_XXXXXXXXXX.p8
#
# Optional:
#   DEVELOPMENT_TEAM  overrides the team in Config/Signing.xcconfig
#   APP_BUNDLE_ID     overrides the bundle ID in Config/Signing.xcconfig
#   BUILD_NUMBER      defaults to a UTC timestamp (must increase for every upload)
#   MARKETING_VERSION overrides the version shown to users (e.g. 1.1)
#   EXPORT_ONLY=1     export an .ipa to build/export instead of uploading
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%y%m%d%H%M)}"
ARCHIVE_PATH="build/CalSync.xcarchive"
EXPORT_PATH="build/export"

auth_args=()
if [[ -n "${ASC_KEY_ID:-}" || -n "${ASC_ISSUER_ID:-}" || -n "${ASC_KEY_PATH:-}" ]]; then
  : "${ASC_KEY_ID:?ASC_KEY_ID is required when using an API key}"
  : "${ASC_ISSUER_ID:?ASC_ISSUER_ID is required when using an API key}"
  : "${ASC_KEY_PATH:?ASC_KEY_PATH is required when using an API key}"
  auth_args=(
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

build_settings=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")
[[ -n "${DEVELOPMENT_TEAM:-}" ]] && build_settings+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
[[ -n "${APP_BUNDLE_ID:-}" ]] && build_settings+=("APP_BUNDLE_ID=$APP_BUNDLE_ID")
[[ -n "${MARKETING_VERSION:-}" ]] && build_settings+=("MARKETING_VERSION=$MARKETING_VERSION")

export_options="Config/ExportOptions.plist"
if [[ "${EXPORT_ONLY:-0}" == "1" ]]; then
  export_options="build/ExportOptions-export.plist"
  mkdir -p build
  cp Config/ExportOptions.plist "$export_options"
  /usr/libexec/PlistBuddy -c "Set :destination export" "$export_options"
fi

echo "==> Archiving build $BUILD_NUMBER"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
xcodebuild archive \
  -project CalSync.xcodeproj \
  -scheme CalSync \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  ${auth_args[@]+"${auth_args[@]}"} \
  "${build_settings[@]}"

echo "==> Exporting"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$export_options" \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates \
  ${auth_args[@]+"${auth_args[@]}"}

if [[ "${EXPORT_ONLY:-0}" == "1" ]]; then
  echo "==> IPA written to $EXPORT_PATH"
else
  echo "==> Uploaded build $BUILD_NUMBER. It will appear in TestFlight after App Store Connect finishes processing."
fi
