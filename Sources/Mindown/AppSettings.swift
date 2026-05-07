import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var downloadDirectory: URL {
        didSet {
            UserDefaults.standard.set(downloadDirectory.path, forKey: Keys.downloadDir)
        }
    }

    @Published var ytDlpPath: String {
        didSet { UserDefaults.standard.set(ytDlpPath, forKey: Keys.ytDlp) }
    }

    @Published var ffmpegPath: String {
        didSet { UserDefaults.standard.set(ffmpegPath, forKey: Keys.ffmpeg) }
    }

    /// When true, audio downloads kick off an Apple iTunes Search API
    /// lookup once the file lands and rewrite its ID3 / iTunes metadata
    /// (title, artist, album, year, genre, track number, cover art).
    @Published var itunesLookupEnabled: Bool {
        didSet { UserDefaults.standard.set(itunesLookupEnabled, forKey: Keys.itunes) }
    }

    /// When true (and the AI sidebar is configured), MetadataEnricher will
    /// ask the configured chat model for the song's lyrics if LRCLib has
    /// no match. Off by default — opt-in because the model may decline,
    /// hallucinate, or charge tokens against the user's API quota.
    @Published var aiLyricsFallbackEnabled: Bool {
        didSet { UserDefaults.standard.set(aiLyricsFallbackEnabled, forKey: Keys.aiLyrics) }
    }

    private enum Keys {
        static let downloadDir = "downloadDirectory"
        static let ytDlp = "ytDlpPath"
        static let ffmpeg = "ffmpegPath"
        static let itunes = "itunesLookupEnabled"
        static let aiLyrics = "aiLyricsFallbackEnabled"
    }

    private init() {
        let defaults = UserDefaults.standard

        if let saved = defaults.string(forKey: Keys.downloadDir),
           !saved.isEmpty,
           FileManager.default.fileExists(atPath: saved) {
            self.downloadDirectory = URL(fileURLWithPath: saved)
        } else {
            let downloads = FileManager.default.urls(
                for: .downloadsDirectory, in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSHomeDirectory())
            self.downloadDirectory = downloads
        }

        self.ytDlpPath = defaults.string(forKey: Keys.ytDlp)
            ?? AppSettings.detectExecutable(["yt-dlp"]) ?? ""

        self.ffmpegPath = defaults.string(forKey: Keys.ffmpeg)
            ?? AppSettings.detectExecutable(["ffmpeg"]) ?? ""

        // Default the iTunes lookup ON for fresh installs; respect any
        // previously saved choice on subsequent launches.
        if defaults.object(forKey: Keys.itunes) == nil {
            self.itunesLookupEnabled = true
        } else {
            self.itunesLookupEnabled = defaults.bool(forKey: Keys.itunes)
        }

        // Default the AI lyrics fallback OFF — the user must consciously
        // opt in because it spends tokens against their chat API quota.
        self.aiLyricsFallbackEnabled = defaults.bool(forKey: Keys.aiLyrics)
    }

    /// Look up an executable by name. Bundled copies inside
    /// `Mindown.app/Contents/Resources/bin/` win over anything on the host,
    /// so end users get a fully self-contained binary with no terminal
    /// install required.
    static func detectExecutable(_ names: [String]) -> String? {
        if let resourcePath = Bundle.main.resourcePath {
            for name in names {
                let bundled = (resourcePath as NSString).appendingPathComponent("bin/\(name)")
                if FileManager.default.isExecutableFile(atPath: bundled) {
                    return bundled
                }
            }
        }
        let searchPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/opt/local/bin",
        ]
        for name in names {
            for dir in searchPaths {
                let path = "\(dir)/\(name)"
                if FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }
        return nil
    }
}
