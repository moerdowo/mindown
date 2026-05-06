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

    private enum Keys {
        static let downloadDir = "downloadDirectory"
        static let ytDlp = "ytDlpPath"
        static let ffmpeg = "ffmpegPath"
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
    }

    static func detectExecutable(_ names: [String]) -> String? {
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
