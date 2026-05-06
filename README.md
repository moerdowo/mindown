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

You need `yt-dlp` and `ffmpeg` on the host. The easiest way:

```bash
brew install yt-dlp ffmpeg
```

The app auto-detects them from `/opt/homebrew/bin` and `/usr/local/bin`.
You can override the paths in **PREFS** if you keep them elsewhere.

## Build

```bash
./build.sh
open YTDown.app
```

This produces a self-contained `YTDown.app` bundle next to the project.

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
