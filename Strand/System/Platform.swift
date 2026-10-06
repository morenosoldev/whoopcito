import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// Thin macOS/iOS shims for the few system side effects the shared app layer needs.
enum Platform {
    static func open(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    static func copyToClipboard(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

extension View {
    /// `.menuStyle(.borderlessButton)` on macOS; iOS menus are borderless by default.
    @ViewBuilder func borderlessMenu() -> some View {
        #if os(macOS)
        self.menuStyle(.borderlessButton)
        #else
        self
        #endif
    }

    /// Escape-to-dismiss on macOS; no-op on iOS.
    @ViewBuilder func onExitCommandIfAvailable(perform action: @escaping () -> Void) -> some View {
        #if os(macOS)
        self.onExitCommand(perform: action)
        #else
        self
        #endif
    }
}

#if os(iOS)
import UniformTypeIdentifiers

/// async wrapper around UIDocumentPickerViewController — the iOS stand-in for NSSavePanel/NSOpenPanel.
@MainActor
enum DocumentPicker {
    /// Let the user choose where to save copies of `urls`. Returns the first destination, or nil if cancelled.
    static func export(_ urls: [URL]) async -> URL? {
        await present(UIDocumentPickerViewController(forExporting: urls, asCopy: true))
    }

    /// Let the user pick one file; returns a local copy, or nil if cancelled.
    static func open(_ types: [UTType]) async -> URL? {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        return await present(picker)
    }

    private static var activeDelegate: Delegate?

    private static func present(_ picker: UIDocumentPickerViewController) async -> URL? {
        guard let host = topViewController() else { return nil }
        return await withCheckedContinuation { continuation in
            let delegate = Delegate { url in
                activeDelegate = nil
                continuation.resume(returning: url)
            }
            activeDelegate = delegate
            picker.delegate = delegate
            host.present(picker, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = (scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    private final class Delegate: NSObject, UIDocumentPickerDelegate {
        let finish: (URL?) -> Void
        init(_ finish: @escaping (URL?) -> Void) { self.finish = finish }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            finish(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish(nil) }
    }
}
#endif
