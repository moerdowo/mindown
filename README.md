# YTDown — Winamp Edition

A native macOS YouTube downloader with a deliberately gaudy, classic-Winamp UI.
Powered by [`yt-dlp`](https://github.com/yt-dlp/yt-dlp) under the hood.

![requires macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-orange)

## Features

- Paste any YouTube (or yt-dlp-supported) URL up top
- Pick container format — **MP4 / WEBM / MKV / MP3 / M4A / OPUS / WAV**
- Pick quality — **BEST / 2160p / 1440p / 1080p / 720p / 480p / 360p**, or audio bitrate
- Hit **DOWNLOAD** → item drops into a queue and starts immediately
- Live LCD-style progress bars with speed / ETA / total size
- Cancel, reveal-in-Finder, clear-completed
- Configurable download directory (persists across launches)
- Beveled chrome, green LCD readouts, blue title bars — full Winamp 2.x cosplay

## Requirements

End users need **nothing**. `yt-dlp` and a static `ffmpeg` are bundled inside
the `.app` and used automatically.

If you'd rather point at a system install (eg `brew install yt-dlp ffmpeg`),
open **PREFS** and override the paths — the app falls back to `$PATH`-style
auto-detection from `/opt/homebrew/bin` and `/usr/local/bin` when nothing is
bundled.

## Build

```bash
./build.sh
open YTDown.app
```

The build script:
1. Downloads `yt-dlp_macos` from the official yt-dlp release
2. Downloads a static `ffmpeg` matching your Mac's architecture
   (`darwin-arm64` on Apple Silicon, `darwin-x64` on Intel)
3. Caches both under `.bin-cache/` so subsequent builds are quick
4. Compiles the Swift app, assembles `YTDown.app`, copies the binaries into
   `Contents/Resources/bin/`, and ad-hoc-signs everything

The resulting `.app` is self-contained — drop it anywhere, no terminal install
needed.

## Develop

```bash
swift build           # debug
swift run YTDownMac   # run from the terminal
swift build -c release
```

The app is a standard SwiftUI Mac app, single executable target, no third-party
Swift dependencies.

## Layout

```
Sources/YTDownMac/
├── App.swift               // @main entry, window styling
├── ContentView.swift       // Main UI — input row, queue, footer
├── SettingsView.swift      // PREFS sheet
├── WinampStyle.swift       // Palette, beveled panels, LCD text, progress bar
├── DownloadModels.swift    // MediaFormat / Quality / DownloadItem
├── DownloadManager.swift   // yt-dlp Process orchestration + progress parsing
└── AppSettings.swift       // UserDefaults-backed preferences
```

## Notes

- The app uses `--progress-template` so progress lines come back as a structured
  pipe-delimited record (percent / speed / ETA / total / title), which is more
  reliable than parsing `[download]` lines.
- Output files are named `%(title).200B [%(id)s].%(ext)s` to keep file names
  unambiguous when the same title appears twice.
- This is not sandboxed/notarised — it's a personal-use tool. Right-click → Open
  the first time if Gatekeeper grumbles.
