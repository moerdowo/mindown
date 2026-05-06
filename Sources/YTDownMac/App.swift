import SwiftUI
import AppKit

@main
struct YTDownMacApp: App {
    @StateObject private var manager = DownloadManager()
    @StateObject private var settings = AppSettings.shared

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("YTDown") {
            ContentView()
                .environmentObject(manager)
                .environmentObject(settings)
                .frame(minWidth: 620, idealWidth: 720, minHeight: 380, idealHeight: 460)
                .ignoresSafeArea(.all)
                .focusEffectDisabled()
                .background(WindowAccessor { window in
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.titlebarSeparatorStyle = .none
                    window.styleMask.insert(.fullSizeContentView)
                    window.isMovableByWindowBackground = true
                    window.backgroundColor = NSColor(WinampPalette.windowBackground)
                    // Hide the standard macOS traffic lights — our custom
                    // _ □ X buttons in WindowChromeTitleBar replace them.
                    window.standardWindowButton(.closeButton)?.isHidden = true
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                    disableFocusRings(on: window.contentView)
                })
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About YTDown") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
            }
        }

        Window("Supported Sites", id: "supported-sites") {
            SupportedSitesView()
                .background(WindowAccessor { window in
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.titlebarSeparatorStyle = .none
                    window.styleMask.insert(.fullSizeContentView)
                    window.isMovableByWindowBackground = true
                    window.backgroundColor = NSColor(WinampPalette.windowBackground)
                    // Hide standard traffic lights — fake _ □ X in the title
                    // bar replaces them, matching the main window's chrome.
                    window.standardWindowButton(.closeButton)?.isHidden = true
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                })
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 560, height: 520)
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Walks the AppKit view tree and turns off the focus ring on every control,
/// catching anything SwiftUI's `.focusEffectDisabled()` doesn't reach.
private func disableFocusRings(on view: NSView?) {
    guard let view else { return }
    if let control = view as? NSControl {
        control.focusRingType = .none
    }
    if let textView = view as? NSTextView {
        textView.focusRingType = .none
    }
    for sub in view.subviews {
        disableFocusRings(on: sub)
    }
}
