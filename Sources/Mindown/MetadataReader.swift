import Foundation

/// Reads tags out of a finished file via the bundled ffmpeg's
/// `-f ffmetadata` dump. Used by the queue row's "LYR" button to surface
/// the embedded USLT / `©lyr` lyrics that MetadataEnricher wrote.
enum MetadataReader {

    /// Synchronous: walks the file with ffmpeg and returns the lyrics body
    /// (or nil if none are stored). Safe to call from a background task.
    static func lyrics(from filePath: String) -> String? {
        let ffmpegPath = AppSettings.shared.ffmpegPath
        guard !filePath.isEmpty,
              FileManager.default.fileExists(atPath: filePath),
              FileManager.default.isExecutableFile(atPath: ffmpegPath) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = ["-hide_banner", "-i", filePath, "-f", "ffmetadata", "-"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return parseFFMetadata(text)
    }

    /// ffmetadata multi-line values continue onto subsequent lines when the
    /// previous line ends with a backslash (`\`). Pull out the `lyrics` /
    /// `lyrics-eng` value, stitching continuations back together.
    private static func parseFFMetadata(_ text: String) -> String? {
        let prefixes = ["lyrics=", "lyrics-eng=", "lyrics-und="]

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var collecting = false
        var pieces: [String] = []

        outer: for line in lines {
            let l = String(line)
            if collecting {
                // The previous line must end with `\` for this line to be
                // part of the value; otherwise the value ended.
                if let last = pieces.last, last.hasSuffix(#"\"#) {
                    pieces[pieces.count - 1] = String(last.dropLast())
                    pieces.append(l)
                    continue
                }
                break outer
            }
            for prefix in prefixes where l.hasPrefix(prefix) {
                pieces.append(String(l.dropFirst(prefix.count)))
                collecting = true
                continue outer
            }
        }

        guard !pieces.isEmpty else { return nil }
        let joined = pieces.joined(separator: "\n")
            .replacingOccurrences(of: #"\\\\"#, with: #"\"#, options: .regularExpression)
            .replacingOccurrences(of: #"\\="#, with: "=", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }
}
