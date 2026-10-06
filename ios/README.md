# Whoopcito — NOOP for iPhone

An iOS build of the NOOP app (shown on the home screen and in TestFlight as **Whoopcito**), produced **without `xcodebuild`** — so it works on a Mac where you
can't get admin rights (Xcode's license acceptance and first-launch setup both need admin).
Device-only: there is no simulator path (CoreSimulator is installed by Xcode's admin-only first
launch), and BLE needs a real phone anyway.

## How it's put together

- `Package.swift` — a SwiftPM executable target. `Sources/NOOPiOS/Shared` is a **symlink** to the
  macOS app's `Strand/` directory, so both apps share one copy of the code. macOS-only files
  (menu bar, notification mirroring, the macOS `@main`) are excluded; the rest is gated with
  `#if os(macOS)` (see `Strand/System/Platform.swift`).
- `Sources/NOOPiOS/App/NOOPiOSApp.swift` — the iOS `@main`.
- `build-ipa.sh` — calls the Xcode toolchain directly (`swift-build`, bypassing the `xcrun` license
  gate), assembles `NOOP.app` by hand (Info.plist, resource bundles, icons), and zips
  `build/NOOP.ipa`. The `.ipa` is **unsigned**.

## Build

Xcode can live anywhere (e.g. `~/Applications/Xcode-27.0.0.app`, installed with
`xcodes install 27.0 --directory ~/Applications --no-superuser`); it never needs to be opened.

```sh
ios/build-ipa.sh                          # → ios/build/NOOP.ipa
XCODE_APP=/path/to/Xcode.app ios/build-ipa.sh
```

## Install on your iPhone

1. Install [Sideloadly](https://sideloadly.io) (drag it into `~/Applications`).
2. Plug in the iPhone, tap **Trust** on the phone.
3. Drag `ios/build/NOOP.ipa` into Sideloadly, enter your Apple ID, Start. Sideloadly signs it.
4. On the iPhone: **Settings → Privacy & Security → Developer Mode → On** (restart when asked),
   then **Settings → General → VPN & Device Management →** trust your Apple ID.
5. Open NOOP and allow Bluetooth.

With a free Apple ID the signature lasts **7 days**; re-sideload to refresh (your data stays).

## TestFlight (via GitHub Actions)

`.github/workflows/testflight.yml` builds with a real Xcode on a GitHub macOS runner, signs with a
cloud-managed distribution certificate, and uploads to TestFlight. Your Mac is not involved, so no
admin is needed. The Xcode target is `NOOPiOS` in `project.yml` (same sources as the SwiftPM
package above, plus `ios/Resources/`: app icon, privacy manifest).

One-time setup (needs a paid Apple Developer account):

1. **Pick a bundle ID you own**, e.g. `dk.morenosoldev.whoopcito` (the default in
   `Signing.xcconfig`). Bundle IDs are global, so change it if that one is taken.
2. **App Store Connect → Apps → +** → New App, iOS, with that bundle ID (register it under
   Certificates, Identifiers & Profiles → Identifiers first if it isn't offered) and a unique name.
   The upload fails if this app record doesn't exist.
3. **App Store Connect → Users and Access → Integrations → App Store Connect API → +** — role
   **Admin** (needed for cloud signing). Note the Key ID and Issuer ID; download the `.p8` (once only).
4. On your GitHub fork → Settings → Secrets and variables → Actions:
   - Secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (paste the whole `.p8` file contents)
   - Variables: `APPLE_TEAM_ID` (developer.apple.com → Membership), `IOS_BUNDLE_ID`
5. Actions → TestFlight → Run workflow (or `gh workflow run testflight.yml`). The build number is
   the workflow run number, so every run uploads a new build.
6. In App Store Connect → TestFlight: add friends as **external testers** (public link or email).
   The first build for external testers goes through Beta App Review (usually ~a day); later builds
   of the same version usually don't. Internal testers skip review but must be users on your team.

If the signing/export step fails, see the comment above the Archive step in the workflow.

## Known gaps on iOS

- No Notifications screen (iOS can't read other apps' notifications).
- "Lock the Mac" automation does nothing on iPhone; Shortcut actions open the Shortcuts app.
- Background sync relies on iOS's `bluetooth-central` background mode and is less reliable than
  the Mac app's — open the app to sync.
- Only one app can hold the strap: quit the official WHOOP app (or turn off its Bluetooth access).
- The layout is the macOS sidebar shell, collapsed by `NavigationSplitView` into a list → detail
  stack; it works but isn't iPhone-tuned yet.
