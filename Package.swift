// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Better",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Better", targets: ["Better"])
    ],
    targets: [
        .executableTarget(
            name: "Better",
            path: "Sources"
        )
    ],
    swiftLanguageModes: [.v5]
)
