import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var manager: DownloadManager
    @EnvironmentObject var settings: AppSettings

    @State private var url: String = ""
    @State private var format: MediaFormat = .mp4
    @State private var quality: Quality = .best
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Outer window chrome.
            WindowChromeTitleBar(
                title: "YTDOWN",
                onMinimize: { NSApp.keyWindow?.miniaturize(nil) },
                onZoom: { NSApp.keyWindow?.zoom(nil) },
                onClose: { NSApplication.shared.terminate(nil) }
            )

            // Main controls section.
            SectionPanel(
                header: {
                    SectionHeader(title: "YTDOWN MAIN") {
                        Button("PREFS") { showSettings = true }
                            .buttonStyle(WinampButtonStyle(minWidth: 50, height: 16))
                    }
                },
                content: { mainControls }
            )

            // Playlist / queue section.
            SectionPanel(
                header: {
                    SectionHeader(title: "YTDOWN PLAYLIST") {
                        HStack(spacing: 6) {
                            LCDText(text: queueCountText, color: WinampPalette.lcdAmber, size: 10)
                            Button("CLR DONE") { manager.clearCompleted() }
                                .buttonStyle(WinampButtonStyle(minWidth: 70, height: 16))
                        }
                    }
                },
                content: { queueList }
            )

            footerBar
        }
        .background(WinampPalette.panelChrome)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(settings)
        }
    }

    // MARK: - Sections

    private var mainControls: some View {
        VStack(spacing: 6) {
            urlRow
            optionsRow
            dirRow
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var urlRow: some View {
        HStack(spacing: 6) {
            LCDText(text: "URL ", color: WinampPalette.lcdGreenDim, size: 11)
                .frame(width: 38, alignment: .leading)
            ZStack {
                WinampPalette.lcdBackground
                TextField(
                    "",
                    text: $url,
                    prompt: Text("paste youtube url…").foregroundColor(WinampPalette.lcdGreenDim)
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(WinampPalette.lcdGreen)
                .padding(.horizontal, 6)
                .onSubmit(submit)
            }
            .frame(height: 22)
            .overlay(BevelOverlay(inset: true))

            Button("PASTE", action: pasteFromClipboard)
                .buttonStyle(WinampButtonStyle(minWidth: 52, height: 22))
        }
    }

    private var optionsRow: some View {
        HStack(spacing: 8) {
            LCDText(text: "FMT ", color: WinampPalette.lcdGreenDim, size: 11)
                .frame(width: 38, alignment: .leading)
            BeveledMenu(label: format.label) {
                ForEach(MediaFormat.allCases) { f in
                    Button(f.label) {
                        format = f
                        let allowed = Quality.qualities(for: f)
                        if !allowed.contains(quality) { quality = allowed.first ?? .best }
                    }
                }
            }
            .frame(width: 80)

            LCDText(text: "QUAL", color: WinampPalette.lcdGreenDim, size: 11)
            BeveledMenu(label: quality.label) {
                ForEach(Quality.qualities(for: format)) { q in
                    Button(q.label) { quality = q }
                }
            }
            .frame(width: 110)

            Spacer()

            Button(action: submit) {
                Text("DOWNLOAD")
            }
            .buttonStyle(WinampButtonStyle(
                tint: WinampPalette.panelLight,
                labelColor: WinampPalette.lcdGreen,
                minWidth: 96, height: 22
            ))
            .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(url.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
    }

    private var dirRow: some View {
        HStack(spacing: 6) {
            LCDText(text: "DIR ", color: WinampPalette.lcdGreenDim, size: 11)
                .frame(width: 38, alignment: .leading)
            ZStack {
                WinampPalette.lcdBackground
                HStack {
                    LCDText(text: settings.downloadDirectory.path,
                            color: WinampPalette.lcdAmber, size: 11)
                    Spacer()
                }
                .padding(.horizontal, 6)
            }
            .frame(height: 20)
            .overlay(BevelOverlay(inset: true))

            Button("BROWSE", action: pickDirectory)
                .buttonStyle(WinampButtonStyle(minWidth: 60, height: 20))
        }
    }

    private var queueList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if manager.queue.isEmpty {
                    LCDText(
                        text: "≪ EMPTY ≫  add a url above and press DOWNLOAD",
                        color: WinampPalette.lcdGreenDim,
                        size: 11
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
                } else {
                    ForEach(Array(manager.queue.enumerated()), id: \.element.id) { idx, item in
                        QueueRow(item: item, index: idx + 1)
                            .environmentObject(manager)
                    }
                }
            }
            .padding(2)
        }
        .frame(minHeight: 240)
    }

    private var footerBar: some View {
        ZStack {
            LinearGradient(
                colors: [WinampPalette.titlebarTop, WinampPalette.titlebarBottom],
                startPoint: .top, endPoint: .bottom
            )
            HStack(spacing: 8) {
                LED(color: WinampPalette.lcdGreen, on: hasActive)
                LCDText(
                    text: hasActive ? "DOWNLOADING…" : "IDLE",
                    color: hasActive ? WinampPalette.lcdGreen : WinampPalette.lcdGreenDim,
                    size: 10
                )
                Spacer()
                LCDText(
                    text: "MAX \(manager.maxConcurrent) PARALLEL",
                    color: WinampPalette.lcdGreenDim, size: 10
                )
                LCDText(
                    text: "  •  yt-dlp \(settings.ytDlpPath.isEmpty ? "MISSING" : "OK")  •  ffmpeg \(settings.ffmpegPath.isEmpty ? "MISSING" : "OK")",
                    color: (settings.ytDlpPath.isEmpty || settings.ffmpegPath.isEmpty)
                        ? WinampPalette.lcdRed
                        : WinampPalette.lcdGreenDim,
                    size: 10
                )
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 22)
        .overlay(BevelOverlay(inset: false))
    }

    // MARK: - Computed

    private var queueCountText: String {
        let total = manager.queue.count
        let active = manager.queue.reduce(into: 0) { acc, item in
            if case .running = item.status { acc += 1 }
        }
        return "\(active) ACTIVE / \(total) TOTAL"
    }

    private var hasActive: Bool {
        manager.queue.contains {
            if case .running = $0.status { return true } else { return false }
        }
    }

    // MARK: - Actions

    private func submit() {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        manager.enqueue(url: trimmed, format: format, quality: quality)
        url = ""
    }

    private func pasteFromClipboard() {
        if let s = NSPasteboard.general.string(forType: .string) {
            url = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.downloadDirectory
        panel.prompt = "Use Folder"
        if panel.runModal() == .OK, let chosen = panel.url {
            settings.downloadDirectory = chosen
        }
    }
}

// MARK: - Queue row (single-line MINPAW playlist style)

struct QueueRow: View {
    @ObservedObject var item: DownloadItem
    @EnvironmentObject var manager: DownloadManager
    let index: Int

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                LCDText(text: String(format: "%2d.", index),
                        color: titleColor, size: 11)
                    .frame(width: 26, alignment: .trailing)

                LCDText(text: item.title, color: titleColor, size: 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)

                LCDText(text: "[\(item.format.label) \(item.quality.label)]",
                        color: WinampPalette.lcdAmber, size: 10)

                LCDText(text: rightStatusText, color: ledColor, size: 11)
                    .frame(width: 64, alignment: .trailing)
            }

            if showsProgress {
                HStack(spacing: 6) {
                    Spacer().frame(width: 26)
                    WinampProgressBar(progress: item.progress, color: ledColor)
                        .frame(height: 8)
                    LCDText(text: secondaryText, color: WinampPalette.lcdGreenDim, size: 9)
                        .frame(maxWidth: 220, alignment: .leading)
                    rowButtons
                }
            } else {
                HStack(spacing: 6) {
                    Spacer()
                    rowButtons
                }
            }

            if case .failed(let msg) = item.status {
                HStack {
                    LCDText(text: "ERR ▶ \(msg)",
                            color: WinampPalette.lcdRed, size: 9)
                    Spacer()
                }
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(rowBackground)
        .overlay(
            Rectangle()
                .stroke(WinampPalette.bevelDark.opacity(0.6), lineWidth: 0.5)
                .opacity(0.5)
        )
    }

    private var titleColor: Color {
        switch item.status {
        case .completed: return WinampPalette.lcdGreen
        case .running:   return WinampPalette.lcdGreen
        case .queued:    return WinampPalette.lcdGreenDim
        case .failed:    return WinampPalette.lcdRed
        case .canceled:  return WinampPalette.lcdGreenDim
        }
    }

    private var ledColor: Color {
        switch item.status {
        case .running:   return WinampPalette.lcdGreen
        case .completed: return WinampPalette.lcdGreen
        case .queued:    return WinampPalette.lcdAmber
        case .failed:    return WinampPalette.lcdRed
        case .canceled:  return WinampPalette.lcdRed
        }
    }

    private var showsProgress: Bool {
        if case .running = item.status { return true }
        return false
    }

    private var rightStatusText: String {
        switch item.status {
        case .running:
            let pct = Int((item.progress * 100).rounded())
            return String(format: "%3d%%", pct)
        case .completed: return "DONE"
        case .queued:    return "QUEUED"
        case .failed:    return "FAIL"
        case .canceled:  return "CXLD"
        }
    }

    private var secondaryText: String {
        let speed = item.speed.isEmpty ? "—" : item.speed
        let eta   = item.eta.isEmpty   ? "—" : item.eta
        let size  = item.totalSize.isEmpty ? "—" : item.totalSize
        return "▼ \(speed)  ETA \(eta)  SZ \(size)"
    }

    private var rowBackground: some View {
        Group {
            if case .running = item.status {
                WinampPalette.selectionBlue.opacity(0.55)
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private var rowButtons: some View {
        switch item.status {
        case .running, .queued:
            Button("STOP") { manager.cancel(item) }
                .buttonStyle(WinampButtonStyle(minWidth: 42, height: 16))
        case .completed:
            Button("SHOW") { manager.revealInFinder(item) }
                .buttonStyle(WinampButtonStyle(minWidth: 42, height: 16))
            Button("DEL") { manager.remove(item) }
                .buttonStyle(WinampButtonStyle(minWidth: 36, height: 16))
        case .failed, .canceled:
            Button("DEL") { manager.remove(item) }
                .buttonStyle(WinampButtonStyle(minWidth: 36, height: 16))
        }
    }
}

// MARK: - Beveled menu

struct BeveledMenu<MenuContent: View>: View {
    var label: String
    @ViewBuilder var content: () -> MenuContent

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                LCDText(text: label, color: WinampPalette.lcdGreen, size: 11)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(WinampPalette.lcdGreenDim)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(WinampPalette.lcdBackground)
            .overlay(BevelOverlay(inset: true))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
    }
}
