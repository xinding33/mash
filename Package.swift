// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mash",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "MashCore"),
        .executableTarget(name: "Mash", dependencies: ["MashCore"], path: "Sources/Mash"),
        .testTarget(name: "MashCoreTests", dependencies: ["MashCore"]),
    ]
)
