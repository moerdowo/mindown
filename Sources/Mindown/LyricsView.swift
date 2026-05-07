import SwiftUI
import AppKit

/// Sheet that surfaces the lyrics embedded in a downloaded audio file. The
/// host passes a file path; we read tags via ffmpeg on appear.
struct LyricsView: View {
    let title: String
    let filePath: String

    @Environment(\.dismiss) private var dismiss
    @State private var lyrics: String? = nil
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            WindowChromeTitleBar(
                title: "LYRICS",
                onMinimize: { dismiss() },
                onZoom: { dismiss() },
                onClose: { dismiss() }
            )

            SectionPanel(
                header: {
                    SectionHeader(title: title.uppercased()) {
                        if let lyrics, !lyrics.isEmpty {
                            Button("COPY") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(lyrics, forType: .string)
                            }
                            .buttonStyle(WinampButtonStyle(minWidth: 56, height: 16))
                        }
                    }
                },
                content: { contentBody }
            )
        }
        .background(WinampPalette.panelChrome)
        .frame(minWidth: 480, minHeight: 540)
        .focusEffectDisabled()
        .onAppear(perform: load)
    }

    @ViewBuilder
    private var contentBody: some View {
        if isLoading {
            LCDText(text: "reading tags…",
                    color: WinampPalette.lcdGreenDim, size: 11)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let lyrics, !lyrics.isEmpty {
            ScrollView {
                Text(lyrics)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(WinampPalette.lcdGreen)
                    .shadow(color: WinampPalette.lcdGreen.opacity(0.4), radius: 0.5)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                LCDText(text: "≪ no lyrics embedded in this file ≫",
                        color: WinampPalette.lcdAmber, size: 11)
                LCDText(text: "this happens when LRCLib has no match for the song.",
                        color: WinampPalette.lcdGreenDim, size: 10)
                LCDText(text: "enable AI LYRICS in PREFS to fall back to your chat model.",
                        color: WinampPalette.lcdGreenDim, size: 10)
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func load() {
        let path = filePath
        Task.detached {
            let result = MetadataReader.lyrics(from: path)
            await MainActor.run {
                self.lyrics = result
                self.isLoading = false
            }
        }
    }
}
