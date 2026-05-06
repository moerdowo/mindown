import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            WindowChromeTitleBar(
                title: "PREFERENCES",
                onMinimize: { dismiss() },
                onZoom: { dismiss() },
                onClose: { dismiss() }
            )

            SectionPanel(
                header: { SectionHeader(title: "YTDOWN PREFS") },
                content: {
                    VStack(alignment: .leading, spacing: 10) {
                        pathRow(
                            label: "DL DIR",
                            value: settings.downloadDirectory.path,
                            action: pickDir
                        )
                        pathRow(
                            label: "YT-DLP",
                            value: settings.ytDlpPath.isEmpty ? "<not found>" : settings.ytDlpPath,
                            action: { pickExecutable(for: \.ytDlpPath) }
                        )
                        pathRow(
                            label: "FFMPEG",
                            value: settings.ffmpegPath.isEmpty ? "<not found>" : settings.ffmpegPath,
                            action: { pickExecutable(for: \.ffmpegPath) }
                        )

                        LCDText(
                            text: "yt-dlp powers downloads. ffmpeg merges audio/video and extracts MP3.",
                            color: WinampPalette.lcdGreenDim,
                            size: 10
                        )
                        LCDText(
                            text: "install with:  brew install yt-dlp ffmpeg",
                            color: WinampPalette.lcdAmber,
                            size: 10
                        )

                        Spacer(minLength: 4)
                        HStack {
                            Spacer()
                            Button("OK") { dismiss() }
                                .buttonStyle(WinampButtonStyle(
                                    tint: WinampPalette.panelLight,
                                    labelColor: WinampPalette.lcdGreen,
                                    minWidth: 80, height: 22
                                ))
                                .keyboardShortcut(.defaultAction)
                        }
                    }
                    .padding(10)
                }
            )
        }
        .frame(width: 560, height: 280)
        .background(WinampPalette.panelChrome)
    }

    private func pathRow(label: String, value: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            LCDText(text: label, color: WinampPalette.lcdGreenDim, size: 11)
                .frame(width: 64, alignment: .leading)
            ZStack {
                WinampPalette.lcdBackground
                HStack {
                    LCDText(text: value, color: WinampPalette.lcdGreen, size: 11)
                    Spacer()
                }
                .padding(.horizontal, 6)
            }
            .frame(height: 22)
            .overlay(BevelOverlay(inset: true))
            Button("CHANGE", action: action)
                .buttonStyle(WinampButtonStyle(minWidth: 64, height: 22))
        }
    }

    private func pickDir() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = settings.downloadDirectory
        panel.prompt = "Use Folder"
        if panel.runModal() == .OK, let url = panel.url {
            settings.downloadDirectory = url
        }
    }

    private func pickExecutable(for keyPath: ReferenceWritableKeyPath<AppSettings, String>) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true
        panel.showsHiddenFiles = true
        panel.prompt = "Choose Binary"
        if panel.runModal() == .OK, let url = panel.url {
            settings[keyPath: keyPath] = url.path
        }
    }
}
