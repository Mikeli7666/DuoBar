#!/bin/bash
set -euo pipefail

EXPECTED_BRANCH="release/1.2.1"
EXPECTED_VERSION="1.2.1"
EXPECTED_BUILD="5"
EXPECTED_BUNDLE_ID="com.mikeli.duobar"
EXPECTED_TEAM="M42BR3TVW4"
IDENTITY="Developer ID Application: Shengwei li (M42BR3TVW4)"
NOTARY_PROFILE="DuoBar-Notary"

ROOT="$(git rev-parse --show-toplevel)"
PROJECT="$(find "$ROOT" -maxdepth 2 -name 'DuoBar.xcodeproj' -type d -print -quit)"
if [[ -z "$PROJECT" ]]; then
  echo "DuoBar.xcodeproj not found" >&2
  exit 1
fi

cd "$ROOT"
[[ "$(git branch --show-current)" == "$EXPECTED_BRANCH" ]] || { echo "Wrong branch" >&2; exit 1; }

settings="$(xcodebuild -project "$PROJECT" -scheme DuoBar -configuration Release -showBuildSettings 2>/dev/null)"
setting() { printf '%s\n' "$settings" | awk -F ' = ' -v key="$1" 'function trim(value) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); return value } { if (trim($1) == key) value=trim($2) } END { print value }'; }
[[ "$(setting MARKETING_VERSION)" == "$EXPECTED_VERSION" ]] || { echo "Unexpected MARKETING_VERSION" >&2; exit 1; }
[[ "$(setting CURRENT_PROJECT_VERSION)" == "$EXPECTED_BUILD" ]] || { echo "Unexpected CURRENT_PROJECT_VERSION" >&2; exit 1; }
[[ "$(setting MACOSX_DEPLOYMENT_TARGET)" == "13.0" ]] || { echo "Unexpected deployment target" >&2; exit 1; }
[[ "$(setting PRODUCT_BUNDLE_IDENTIFIER)" == "$EXPECTED_BUNDLE_ID" ]] || { echo "Unexpected bundle identifier" >&2; exit 1; }
[[ "$(setting DEVELOPMENT_TEAM)" == "$EXPECTED_TEAM" ]] || { echo "Unexpected development team" >&2; exit 1; }

security find-identity -v -p codesigning | grep -Fq "\"$IDENTITY\"" || {
  echo "Required Developer ID identity is not visible" >&2
  exit 1
}

WORK="$(mktemp -d /tmp/duobar-1.2.1-release.XXXXXX)"
STAGE="$WORK/stage"
DERIVED="$WORK/DerivedData"
APP="$DERIVED/Build/Products/Release/DuoBar.app"
ZIP="$WORK/DuoBar-1.2.1-notarization.zip"
DMG="$WORK/DuoBar-1.2.1.dmg"
FINAL_DIR="$ROOT/release/1.2.1/final"
FINAL_DMG="$FINAL_DIR/DuoBar-1.2.1.dmg"
MOUNT=""
cleanup() {
  if [[ -n "$MOUNT" ]] && mount | grep -Fq " on $MOUNT "; then
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT
mkdir -p "$STAGE" "$FINAL_DIR"

xcodebuild -project "$PROJECT" -scheme DuoBar -configuration Release \
  -derivedDataPath "$DERIVED" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM="$EXPECTED_TEAM" \
  build

# Re-sign the complete final app explicitly with a secure Developer ID timestamp
# before it is submitted to Apple notarization.
codesign --force --deep --timestamp --options runtime \
  --entitlements "$ROOT/DuoBar/DuoBar.entitlements" \
  --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
[[ "$(file "$APP/Contents/MacOS/DuoBar")" == *arm64* && "$(file "$APP/Contents/MacOS/DuoBar")" == *x86_64* ]] || { echo "App is not Universal 2" >&2; exit 1; }
codesign -dv --verbose=4 "$APP" 2> "$WORK/codesign.txt"
grep -Fq "Identifier=$EXPECTED_BUNDLE_ID" "$WORK/codesign.txt"
grep -Fq "Authority=$IDENTITY" "$WORK/codesign.txt" || { echo "Final app is not signed by the expected Developer ID Application identity" >&2; exit 1; }
grep -Fq "TeamIdentifier=$EXPECTED_TEAM" "$WORK/codesign.txt"
grep -Fq 'flags=0x10000(runtime)' "$WORK/codesign.txt"
grep -Fq 'Timestamp=' "$WORK/codesign.txt" || { echo "Final app signature has no secure timestamp" >&2; exit 1; }
codesign -d --entitlements :- "$APP" > "$WORK/entitlements.plist" 2>/dev/null
grep -Fq 'com.apple.security.personal-information.location' "$WORK/entitlements.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" == "$EXPECTED_VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")" == "$EXPECTED_BUILD" ]]

ditto -c -k --keepParent "$APP" "$ZIP"
app_notary="$(xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
printf '%s\n' "$app_notary" > "$WORK/app-notary.json"
grep -Eq '"status"[[:space:]]*:[[:space:]]*"Accepted"' "$WORK/app-notary.json" || { echo "App notarization was not Accepted" >&2; exit 1; }
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=4 "$APP"

ditto "$APP" "$STAGE/DuoBar.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "DuoBar 1.2.1" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
codesign --verify --verbose=2 "$DMG"

dmg_notary="$(xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
printf '%s\n' "$dmg_notary" > "$WORK/dmg-notary.json"
grep -Eq '"status"[[:space:]]*:[[:space:]]*"Accepted"' "$WORK/dmg-notary.json" || { echo "DMG notarization was not Accepted" >&2; exit 1; }
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"
cp "$DMG" "$FINAL_DMG"
xcrun stapler validate "$FINAL_DMG"

ATTACH_PLIST="$WORK/attach.plist"
hdiutil attach "$FINAL_DMG" -nobrowse -plist > "$ATTACH_PLIST"
MOUNT="$(plutil -p "$ATTACH_PLIST" | awk -F'=> ' '/"mount-point"/ { gsub(/^"|"$/, "", $2); if ($2 != "null" && length($2) > 0) { print $2; exit } }')"
if [[ -z "$MOUNT" ]]; then
  echo "No DMG mount point found in hdiutil attach output" >&2
  exit 1
fi
MOUNT_APP="$MOUNT/DuoBar.app"
codesign --verify --deep --strict --verbose=2 "$MOUNT_APP"
spctl --assess --type execute --verbose=4 "$MOUNT_APP"
xcrun stapler validate "$MOUNT_APP"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$MOUNT_APP/Contents/Info.plist")" == "$EXPECTED_BUNDLE_ID" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MOUNT_APP/Contents/Info.plist")" == "$EXPECTED_VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$MOUNT_APP/Contents/Info.plist")" == "$EXPECTED_BUILD" ]]
[[ "$(file "$MOUNT_APP/Contents/MacOS/DuoBar")" == *arm64* && "$(file "$MOUNT_APP/Contents/MacOS/DuoBar")" == *x86_64* ]]
hdiutil detach "$MOUNT" >/dev/null
MOUNT=""

echo "FINAL RELEASE REPORT"
echo "Version: $EXPECTED_VERSION"
echo "Build: $EXPECTED_BUILD"
echo "Bundle ID: $EXPECTED_BUNDLE_ID"
echo "Architectures: arm64 x86_64"
echo "Developer ID: $IDENTITY"
echo "TeamIdentifier: $EXPECTED_TEAM"
echo "Hardened Runtime: verified"
echo "App notarization: Accepted"
echo "DMG notarization: Accepted"
echo "Staple validation: passed"
echo "Gatekeeper: passed"
echo "DMG size: $(stat -f%z "$FINAL_DMG") bytes"
echo "SHA-256: $(shasum -a 256 "$FINAL_DMG" | awk '{print $1}')"
echo "Final artifact: $FINAL_DMG"
