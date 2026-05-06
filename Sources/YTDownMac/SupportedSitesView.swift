import SwiftUI
import AppKit

/// Window content that displays the list of sites yt-dlp can extract from.
/// The list is bundled at build time as `Resources/supportedsites.md`; if it
/// is missing for any reason we fall back to running the bundled
/// `yt-dlp --list-extractors`.
struct SupportedSitesView: View {
    @State private var rawText: String = ""
    @State private var lines: [String] = []
    @State private var filter: String = ""
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Standard macOS close/min/zoom buttons sit on the left at native
            // positions; leadingInset 76 keeps the title clear of them.
            WindowChromeTitleBar(title: "SUPPORTED SITES", leadingInset: 76)
                .ignoresSafeArea(edges: .top)

            SectionPanel(
                header: {
                    SectionHeader(title: "yt-dlp EXTRACTORS") {
                        LCDText(
                            text: "\(filteredLines.count) MATCH\(filteredLines.count == 1 ? "" : "ES")",
                            color: WinampPalette.lcdAmber, size: 10
                        )
                    }
                },
                content: { contentBody }
            )
        }
        .background(WinampPalette.panelChrome)
        .frame(minWidth: 520, minHeight: 480)
        .focusEffectDisabled()
        .onAppear(perform: load)
    }

    @ViewBuilder
    private var contentBody: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                LCDText(text: "FIND", color: WinampPalette.lcdGreenDim, size: 11)
                    .frame(width: 38, alignment: .leading)
                ZStack {
                    WinampPalette.lcdBackground
                    TextField(
                        "",
                        text: $filter,
                        prompt: Text("type to filter (eg. youtube, tiktok)…")
                            .foregroundColor(WinampPalette.lcdGreenDim)
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(WinampPalette.lcdGreen)
                    .padding(.horizontal, 6)
                }
                .frame(height: 22)
                .overlay(BevelOverlay(inset: true))

                if !filter.isEmpty {
                    Button("CLR") { filter = "" }
                        .buttonStyle(WinampButtonStyle(minWidth: 42, height: 22))
                }
            }

            if isLoading {
                LCDText(text: "loading…", color: WinampPalette.lcdGreenDim, size: 11)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else if filteredLines.isEmpty {
                LCDText(text: "≪ no matches ≫",
                        color: WinampPalette.lcdAmber, size: 11)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredLines.indices, id: \.self) { i in
                            LCDText(text: filteredLines[i],
                                    color: WinampPalette.lcdGreen, size: 11)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 1)
                                .padding(.horizontal, 6)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(8)
    }

    private var filteredLines: [String] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return lines }
        return lines.filter { $0.lowercased().contains(q) }
    }

    // MARK: - Loading

    private func load() {
        DispatchQueue.global(qos: .userInitiated).async {
            let text = loadFromBundle() ?? loadFromYtDlp() ?? "Could not load supported sites list."
            let split = text
                .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
                .map(String.init)
                .compactMap(cleanMarkdownLine)
            DispatchQueue.main.async {
                self.rawText = text
                self.lines = split
                self.isLoading = false
            }
        }
    }

    /// Strip the markdown noise out of a line from supportedsites.md so the
    /// list reads as plain text. Returns nil for headers, intro paragraphs,
    /// and blank lines so we only keep the actual extractor entries.
    private func cleanMarkdownLine(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("#") { return nil }              // headings
        if !trimmed.hasPrefix("-") && !trimmed.hasPrefix("*") {
            return nil                                         // intro paragraphs
        }

        var s = trimmed
        // drop the leading bullet marker
        if let r = s.range(of: #"^[-*]\s+"#, options: .regularExpression) {
            s.removeSubrange(r)
        }
        // [text](url) -> text
        s = s.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]*\)"#,
            with: "$1",
            options: .regularExpression
        )
        // **bold** -> bold
        s = s.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        // *italic* -> italic
        s = s.replacingOccurrences(
            of: #"\*([^*]+)\*"#,
            with: "$1",
            options: .regularExpression
        )
        // `code` -> code
        s = s.replacingOccurrences(of: "`", with: "")
        // collapse any leftover double spaces
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private func loadFromBundle() -> String? {
        guard let path = Bundle.main.path(forResource: "supportedsites", ofType: "md"),
              let data = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return data
    }

    /// Fallback: ask the bundled yt-dlp for its extractor list. Slower and
    /// less pretty than the markdown file, but always available.
    private func loadFromYtDlp() -> String? {
        let path = AppSettings.shared.ytDlpPath
        guard !path.isEmpty,
              FileManager.default.isExecutableFile(atPath: path) else {
            return nil
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--list-extractors"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
