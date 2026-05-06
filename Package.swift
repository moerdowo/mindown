// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YTDownMac",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "YTDownMac",
            path: "Sources/YTDownMac"
        )
    ]
)
