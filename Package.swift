// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mindown",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Mindown",
            path: "Sources/Mindown"
        )
    ]
)
