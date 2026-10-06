// swift-tools-version: 5.9
// iOS app target for NOOP, built with SwiftPM directly (no xcodebuild) — see ios/README.md.
// `Sources/NOOPiOS/Shared` is a symlink to the macOS app's `Strand/` directory; the macOS-only
// files are excluded below and the rest is gated with `#if os(macOS)`.
import PackageDescription

let package = Package(
    name: "NOOPiOS",
    platforms: [.iOS(.v16), .macOS(.v13)],
    dependencies: [
        .package(path: "../Packages/WhoopProtocol"),
        .package(path: "../Packages/WhoopStore"),
        .package(path: "../Packages/StrandAnalytics"),
        .package(path: "../Packages/StrandImport"),
        .package(path: "../Packages/StrandDesign"),
    ],
    targets: [
        .executableTarget(
            name: "NOOPiOS",
            dependencies: [
                "WhoopProtocol", "WhoopStore", "StrandAnalytics", "StrandImport", "StrandDesign",
            ],
            exclude: [
                "Shared/App/StrandApp.swift",
                "Shared/MenuBar",
                "Shared/Resources",
                "Shared/Data/NotificationSettingsStore.swift",
                "Shared/Screens/NotificationSettingsView.swift",
            ]
        ),
    ]
)
