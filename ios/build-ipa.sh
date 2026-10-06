#!/usr/bin/env bash
# Build an unsigned NOOP.ipa for iPhone without xcodebuild (so no admin / license step needed).
# Calls the Xcode toolchain directly, assembles NOOP.app by hand, and zips it for sideloading
# (Sideloadly / AltStore re-sign it with your Apple ID). See ios/README.md.
#
#   ios/build-ipa.sh              # → ios/build/NOOP.ipa
#   XCODE_APP=/path/Xcode.app ios/build-ipa.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

XCODE_APP="${XCODE_APP:-$(ls -d "$HOME"/Applications/Xcode*.app /Applications/Xcode*.app 2>/dev/null | sort -V | tail -1 || true)}"
[ -d "$XCODE_APP" ] || { echo "Xcode not found — set XCODE_APP=/path/to/Xcode.app" >&2; exit 1; }
DEV="$XCODE_APP/Contents/Developer"
TOOLS="$DEV/Toolchains/XcodeDefault.xctoolchain/usr/bin"
SDK="$DEV/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
SDK_VERSION="$(plutil -extract Version raw "$SDK/SDKSettings.plist")"
MIN_IOS="16.0"
TRIPLE="arm64-apple-ios$MIN_IOS"

SCRATCH="$HERE/.build"
OUT="$HERE/build"
APP="$OUT/Payload/NOOP.app"

echo "▸ Xcode: $XCODE_APP (iOS SDK $SDK_VERSION)"
echo "▸ Compiling…"
# --build-system native: the default (swift-build) engine can't resolve the iphoneos platform
# without xcodebuild's setup. -platform_version stamps the real SDK so iOS doesn't run us in
# legacy-compat mode.
"$TOOLS/swift-build" --package-path "$HERE" --build-system native -c release \
    --scratch-path "$SCRATCH" --sdk "$SDK" --triple "$TRIPLE" \
    -Xlinker -platform_version -Xlinker ios -Xlinker "$MIN_IOS" -Xlinker "$SDK_VERSION"
PRODUCTS="$SCRATCH/arm64-apple-ios/release"

echo "▸ Assembling NOOP.app…"
rm -rf "$OUT"
mkdir -p "$APP"
cp "$PRODUCTS/NOOPiOS" "$APP/NOOP"
# SwiftPM resource bundles (whoop_protocol.json etc.); Bundle.module looks for them in the app root.
for bundle in "$PRODUCTS"/*.bundle; do cp -R "$bundle" "$APP/"; done

# Home-screen icon from the 1024px master (loose PNGs; no actool needed).
ICON="$HERE/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
sips -z 120 120 "$ICON" --out "$APP/AppIcon60x60@2x.png" >/dev/null
sips -z 180 180 "$ICON" --out "$APP/AppIcon60x60@3x.png" >/dev/null
sips -z 152 152 "$ICON" --out "$APP/AppIcon76x76@2x~ipad.png" >/dev/null

cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleDisplayName</key><string>NOOP</string>
	<key>CFBundleName</key><string>NOOP</string>
	<key>CFBundleExecutable</key><string>NOOP</string>
	<key>CFBundleIdentifier</key><string>com.noopapp.noop.ios</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>CFBundleSupportedPlatforms</key><array><string>iPhoneOS</string></array>
	<key>CFBundleIcons</key>
	<dict>
		<key>CFBundlePrimaryIcon</key>
		<dict><key>CFBundleIconFiles</key><array><string>AppIcon60x60</string></array></dict>
	</dict>
	<key>CFBundleIcons~ipad</key>
	<dict>
		<key>CFBundlePrimaryIcon</key>
		<dict><key>CFBundleIconFiles</key><array><string>AppIcon60x60</string><string>AppIcon76x76</string></array></dict>
	</dict>
	<key>DTPlatformName</key><string>iphoneos</string>
	<key>DTSDKName</key><string>iphoneos$SDK_VERSION</string>
	<key>DTPlatformVersion</key><string>$SDK_VERSION</string>
	<key>MinimumOSVersion</key><string>$MIN_IOS</string>
	<key>LSRequiresIPhoneOS</key><true/>
	<key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
	<key>UIRequiredDeviceCapabilities</key><array><string>arm64</string><string>bluetooth-le</string></array>
	<key>UILaunchScreen</key><dict/>
	<key>UIApplicationSceneManifest</key>
	<dict><key>UIApplicationSupportsMultipleScenes</key><false/></dict>
	<key>UISupportedInterfaceOrientations</key>
	<array><string>UIInterfaceOrientationPortrait</string></array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UIBackgroundModes</key><array><string>bluetooth-central</string></array>
	<key>NSBluetoothAlwaysUsageDescription</key>
	<string>NOOP connects directly to your WHOOP strap over Bluetooth to read heart rate, R-R intervals, battery, and sensor data locally on your iPhone. Nothing leaves your device.</string>
	<key>ITSAppUsesNonExemptEncryption</key><false/>
</dict>
</plist>
PLIST
plutil -lint "$APP/Info.plist" >/dev/null

echo "▸ Packaging NOOP.ipa…"
(cd "$OUT" && zip -qry NOOP.ipa Payload)
echo "✓ $OUT/NOOP.ipa ($(du -h "$OUT/NOOP.ipa" | cut -f1)) — unsigned; sideload with Sideloadly."
