import SwiftUI
import AppKit

@main
struct YTDownMacApp: App {
    @StateObject private var manager: DownloadManager
    @StateObject private var settings: AppSettings
    @StateObject private var aiSettings: AISettings
    @StateObject private var chatVM: ChatViewModel

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        let mgr = DownloadManager()
        _manager   = StateObject(wrappedValue: mgr)
        _settings  = StateObject(wrappedValue: AppSettings.shared)
        _aiSettings = StateObject(wrappedValue: AISettings.shared)
        _chatVM    = StateObject(wrappedValue: ChatViewModel(manager: mgr))
    }

    var body: some Scene {
        WindowGroup("YTDown") {
            ContentView()
                .environmentObject(manager)
                .environmentObject(settings)
                .environmentObject(aiSettings)
                .environmentObject(chatVM)
                .frame(
                    minWidth: aiSettings.sidebarVisible ? 980 : 620,
                    idealWidth: aiSettings.sidebarVisible ? 1080 : 720,
                    minHeight: 420, idealHeight: 520
                )
                .ignoresSafeArea(.all)
                .focusEffectDisabled()
                .background(WindowAccessor { window in
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.titlebarSeparatorStyle = .none
                    window.styleMask.insert(.fullSizeContentView)
                    window.isMovableByWindowBackground = true
                    window.backgroundColor = NSColor(WinampPalette.windowBackground)
                    // Use the standard macOS close/minimize/zoom traffic
                    // lights — guaranteed to render reliably across versions.
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
