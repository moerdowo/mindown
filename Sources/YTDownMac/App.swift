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
                .frame(minWidth: 620, idealWidth: 720, minHeight: 600, idealHeight: 720)
                .focusEffectDisabled()
                .background(WindowAccessor { window in
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.styleMask.insert(.fullSizeContentView)
                    window.isMovableByWindowBackground = true
                    window.backgroundColor = NSColor(WinampPalette.windowBackground)
                    disableFocusRings(on: window.contentView)
                })
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About YTDown") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
            }
        }
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
