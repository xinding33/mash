// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mash",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Mash", path: "Sources/Mash")
    ]
)
