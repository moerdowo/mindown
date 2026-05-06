import Foundation
import SwiftUI
import AppKit

@MainActor
final class DownloadManager: ObservableObject {
    @Published var queue: [DownloadItem] = []
    @Published var lastError: String? = nil

    /// Cap on concurrent yt-dlp processes. Extras stay queued and start as slots free up.
    let maxConcurrent: Int = 5

    private var processes: [UUID: Process] = [:]

    /// Add a new item to the queue. It starts immediately if a slot is free,
    /// otherwise waits in FIFO order until an in-flight download finishes.
    func enqueue(url: String, format: MediaFormat, quality: Quality) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = DownloadItem(url: trimmed, format: format, quality: quality)
        queue.insert(item, at: 0)
        pumpQueue()
    }

    private var runningCount: Int {
        queue.reduce(into: 0) { acc, item in
            if case .running = item.status { acc += 1 }
        }
    }

    /// Start as many queued items as the concurrency cap allows, oldest first.
    private func pumpQueue() {
        var slots = maxConcurrent - runningCount
        guard slots > 0 else { return }
        let waiting = queue
            .filter { if case .queued = $0.status { return true } else { return false } }
            .sorted { $0.createdAt < $1.createdAt }
        for item in waiting {
            if slots <= 0 { break }
            start(item)
            slots -= 1
        }
    }

    func cancel(_ item: DownloadItem) {
        if let p = processes[item.id], p.isRunning {
            p.terminate()
        }
        if case .running = item.status {
            item.status = .canceled
        } else if case .queued = item.status {
            item.status = .canceled
        }
    }

    func remove(_ item: DownloadItem) {
        cancel(item)
        queue.removeAll { $0.id == item.id }
        processes.removeValue(forKey: item.id)
    }

    func clearCompleted() {
        let stillActive = queue.filter {
            switch $0.status {
            case .queued, .running: return true
            default: return false
            }
        }
        queue = stillActive
    }

    func revealInFinder(_ item: DownloadItem) {
        let path = item.outputPath
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Private

    private func start(_ item: DownloadItem) {
        let settings = AppSettings.shared
        guard !settings.ytDlpPath.isEmpty,
              FileManager.default.isExecutableFile(atPath: settings.ytDlpPath) else {
            item.status = .failed("yt-dlp not found — set its path in PREFS")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: settings.ytDlpPath)
        process.arguments = buildArguments(for: item, settings: settings)

        // Make the bundled ffmpeg discoverable to yt-dlp.
        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
        let existingPath = env["PATH"] ?? ""
        env["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        item.status = .running
        item.progress = 0
        processes[item.id] = process

        // Read stdout line-by-line to update progress.
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self, weak item] handle in
            guard let self, let item else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let chunk = String(data: data, encoding: .utf8) ?? ""
            for line in chunk.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                Task { @MainActor in
                    self.handleStdoutLine(trimmed, for: item)
                }
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak item] handle in
            guard let item else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let s = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                item.lastLine = s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        process.terminationHandler = { [weak self, weak item] proc in
            guard let self, let item else { return }
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                self.handleTermination(proc, item: item)
            }
        }

        do {
            try process.run()
        } catch {
            item.status = .failed("Could not launch yt-dlp: \(error.localizedDescription)")
        }
    }

    private func buildArguments(for item: DownloadItem, settings: AppSettings) -> [String] {
        var args: [String] = []

        // Output template: title + extension under the chosen download dir.
        let outTemplate = settings.downloadDirectory
            .appendingPathComponent("%(title).200B [%(id)s].%(ext)s")
            .path
        args += ["-o", outTemplate]

        // Sensible defaults.
        args += ["--no-playlist", "--newline", "--no-colors", "--no-mtime"]

        // ffmpeg path (needed for merging video+audio and audio extraction).
        if !settings.ffmpegPath.isEmpty {
            args += ["--ffmpeg-location", settings.ffmpegPath]
        }

        // Format/quality selection.
        if item.format.isAudio {
            args += ["-x", "--audio-format", item.format.rawValue]
            if let kbps = item.quality.audioKbps {
                args += ["--audio-quality", "\(kbps)K"]
            } else {
                args += ["--audio-quality", "0"]
            }
        } else {
            let h = item.quality.heightLimit
            let heightFilter = h.map { "[height<=\($0)]" } ?? ""
            let ext = item.format.rawValue
            // Prefer matching extension at the chosen height, otherwise fall back to best of any container and remux.
            let format = "bv*[ext=\(ext)]\(heightFilter)+ba[ext=m4a]/bv*\(heightFilter)+ba/b\(heightFilter)/b"
            args += ["-f", format, "--merge-output-format", ext]
        }

        // Structured progress lines we can parse.
        args += [
            "--progress-template",
            "DL|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._total_bytes_str)s|%(info.title)s"
        ]
        // Final filename emitted after any post-processing/merge.
        args += ["--print", "after_move:FILE|%(filepath)s"]
        // Title becomes available even before the first progress tick.
        args += ["--print", "before_dl:TITLE|%(title)s"]

        args.append(item.url)
        return args
    }

    private func handleStdoutLine(_ line: String, for item: DownloadItem) {
        item.lastLine = line

        if line.hasPrefix("TITLE|") {
            let title = String(line.dropFirst("TITLE|".count))
            if !title.isEmpty { item.title = title }
            return
        }
        if line.hasPrefix("FILE|") {
            let path = String(line.dropFirst("FILE|".count))
            if !path.isEmpty { item.outputPath = path }
            return
        }
        if line.hasPrefix("DL|") {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            // DL | percent | speed | eta | totalBytes | title
            if parts.count >= 5 {
                let pct = parts[1].trimmingCharacters(in: .whitespaces)
                if let val = parsePercent(pct) {
                    item.progress = val
                }
                item.speed = parts[2].trimmingCharacters(in: .whitespaces)
                item.eta   = parts[3].trimmingCharacters(in: .whitespaces)
                item.totalSize = parts[4].trimmingCharacters(in: .whitespaces)
                if parts.count >= 6 && item.title == item.url {
                    let t = parts[5].trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty && t != "NA" { item.title = t }
                }
            }
            return
        }
        // Fallback: parse classic "[download]   3.4% of ..." lines.
        if line.hasPrefix("[download]"), let pct = extractClassicPercent(line) {
            item.progress = pct
        }
    }

    private func handleTermination(_ proc: Process, item: DownloadItem) {
        processes.removeValue(forKey: item.id)
        defer { pumpQueue() }
        if case .canceled = item.status { return }
        if proc.terminationStatus == 0 {
            item.progress = 1.0
            item.status = .completed
            item.eta = ""
            item.speed = ""
        } else {
            let msg = item.lastLine.isEmpty
                ? "yt-dlp exited with code \(proc.terminationStatus)"
                : item.lastLine
            item.status = .failed(msg)
        }
    }

    private func parsePercent(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty || cleaned == "NA" { return nil }
        guard let d = Double(cleaned) else { return nil }
        return max(0, min(1, d / 100.0))
    }

    private func extractClassicPercent(_ line: String) -> Double? {
        // Match the first "<num>%" token in the line.
        guard let pctRange = line.range(of: #"\d+(\.\d+)?%"#, options: .regularExpression) else {
            return nil
        }
        let token = line[pctRange].dropLast() // drop %
        guard let val = Double(token) else { return nil }
        return max(0, min(1, val / 100.0))
    }
}
