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
            WinampTitleBar(title: "YTDOWN ◇ WINAMP-EDITION", onSettings: {
                showSettings = true
            })

            // Main control panel — URL + format + quality + GO.
            BeveledPanel(fill: WinampPalette.panelMid) {
                VStack(spacing: 8) {
                    inputRow
                    optionsRow
                    statusRow
                }
            }
            .padding(8)

            // Queue / playlist section.
            BeveledPanel(fill: WinampPalette.panelDark) {
                VStack(spacing: 4) {
                    queueHeader
                    Divider().background(WinampPalette.bevelDark)
                    queueList
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            footerBar
        }
        .background(WinampPalette.windowBackground)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
    }

    // MARK: - Sections

    private var inputRow: some View {
        HStack(spacing: 6) {
            LCDText(text: "URL", color: WinampPalette.lcdGreenDim, size: 11)
                .frame(width: 30, alignment: .leading)
            LCDPanel {
                TextField("", text: $url, prompt: Text("paste youtube url…").foregroundColor(WinampPalette.lcdGreenDim))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(WinampPalette.lcdGreen)
                    .onSubmit(submit)
            }
            .frame(height: 22)

            Button(action: pasteFromClipboard) {
                Text("PASTE")
            }
            .buttonStyle(WinampButtonStyle(minWidth: 50, height: 22))
        }
    }

    private var optionsRow: some View {
        HStack(spacing: 8) {
            LCDText(text: "FMT", color: WinampPalette.lcdGreenDim, size: 11)
                .frame(width: 30, alignment: .leading)

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
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("DOWNLOAD")
                }
            }
            .buttonStyle(WinampButtonStyle(
                tint: WinampPalette.titlebarTop,
                labelColor: WinampPalette.lcdGreen,
                minWidth: 110, height: 26
            ))
            .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(url.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            LCDText(text: "DIR", color: WinampPalette.lcdGreenDim, size: 11)
                .frame(width: 30, alignment: .leading)
            LCDPanel {
                HStack {
                    LCDText(
                        text: settings.downloadDirectory.path,
                        color: WinampPalette.lcdAmber,
                        size: 11
                    )
                    Spacer()
                }
            }
            .frame(height: 20)

            Button(action: pickDirectory) {
                Text("BROWSE")
            }
            .buttonStyle(WinampButtonStyle(minWidth: 60, height: 20))
        }
    }

    private var queueHeader: some View {
        HStack {
            LCDText(text: "♪ DOWNLOAD QUEUE", color: WinampPalette.lcdGreen, size: 11)
            Spacer()
            LCDText(
                text: "\(manager.queue.count) ITEMS",
                color: WinampPalette.lcdGreenDim,
                size: 10
            )
            Button("CLR DONE") {
                manager.clearCompleted()
            }
            .buttonStyle(WinampButtonStyle(minWidth: 70, height: 18))
        }
        .padding(.horizontal, 4)
    }

    private var queueList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if manager.queue.isEmpty {
                    LCDText(
                        text: "≪ EMPTY ≫  add a url above and press DOWNLOAD",
                        color: WinampPalette.lcdGreenDim,
                        size: 11
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
                } else {
                    ForEach(manager.queue) { item in
                        QueueRow(item: item)
                            .environmentObject(manager)
                    }
                }
            }
            .padding(4)
        }
        .frame(minHeight: 180)
    }

    private var footerBar: some View {
        ZStack {
            LinearGradient(
                colors: [WinampPalette.panelMid, WinampPalette.panelDark],
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
                    text: "yt-dlp \(settings.ytDlpPath.isEmpty ? "MISSING" : "OK")  •  ffmpeg \(settings.ffmpegPath.isEmpty ? "MISSING" : "OK")",
                    color: (settings.ytDlpPath.isEmpty || settings.ffmpegPath.isEmpty) ? WinampPalette.lcdRed : WinampPalette.lcdGreenDim,
                    size: 10
                )
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 22)
        .overlay(Rectangle().stroke(WinampPalette.bevelDark, lineWidth: 1))
    }

    private var hasActive: Bool {
        manager.queue.contains { if case .running = $0.status { return true } else { return false } }
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

// MARK: - Queue row

struct QueueRow: View {
    @ObservedObject var item: DownloadItem
    @EnvironmentObject var manager: DownloadManager

    var body: some View {
        BeveledPanel(inset: true, fill: WinampPalette.lcdBackground) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    LED(color: ledColor, on: item.status == .running || item.status == .completed)
                    LCDText(text: item.title, color: WinampPalette.lcdGreen, size: 11)
                    Spacer()
                    LCDText(text: "[\(item.format.label) · \(item.quality.label)]",
                            color: WinampPalette.lcdAmber, size: 10)
                    LCDText(text: item.status.label, color: ledColor, size: 10)
                }

                WinampProgressBar(progress: item.progress, color: ledColor)
                    .frame(height: 8)

                HStack(spacing: 12) {
                    LCDText(text: percentText, color: WinampPalette.lcdGreen, size: 10)
                    LCDText(text: "▼ \(item.speed.isEmpty ? "—" : item.speed)",
                            color: WinampPalette.lcdGreenDim, size: 10)
                    LCDText(text: "ETA \(item.eta.isEmpty ? "—" : item.eta)",
                            color: WinampPalette.lcdGreenDim, size: 10)
                    LCDText(text: "SZ \(item.totalSize.isEmpty ? "—" : item.totalSize)",
                            color: WinampPalette.lcdGreenDim, size: 10)
                    Spacer()
                    rowButtons
                }
                if case .failed(let msg) = item.status {
                    LCDText(text: "ERR ▶ \(msg)", color: WinampPalette.lcdRed, size: 10)
                }
            }
        }
        .padding(.vertical, 1)
    }

    private var percentText: String {
        let p = Int((item.progress * 100).rounded())
        return String(format: "%3d%%", p)
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

    @ViewBuilder
    private var rowButtons: some View {
        switch item.status {
        case .running, .queued:
            Button("STOP") { manager.cancel(item) }
                .buttonStyle(WinampButtonStyle(minWidth: 44, height: 16))
        case .completed:
            Button("SHOW") { manager.revealInFinder(item) }
                .buttonStyle(WinampButtonStyle(minWidth: 44, height: 16))
            Button("DEL")  { manager.remove(item) }
                .buttonStyle(WinampButtonStyle(minWidth: 36, height: 16))
        case .failed, .canceled:
            Button("DEL")  { manager.remove(item) }
                .buttonStyle(WinampButtonStyle(minWidth: 36, height: 16))
        }
    }
}

// MARK: - Beveled menu (looks like the rest of the chrome instead of a stock SwiftUI Menu).

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
            .overlay(
                Rectangle().stroke(WinampPalette.bevelDark, lineWidth: 1)
            )
            .overlay(
                Rectangle().stroke(WinampPalette.bevelLight.opacity(0.4), lineWidth: 1).padding(1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
    }
}
