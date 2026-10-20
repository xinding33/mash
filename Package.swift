// swift-tools-version: 6.0
import PackageDescription

// No packages. Logic that can be tested without the hardware lives in MashCore.
let package = Package(
    name: "Mash",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Mash", targets: ["Mash"])],
    targets: [
        .target(name: "MashCore"),
        .executableTarget(name: "Mash", dependencies: ["MashCore"]),
        .testTarget(name: "MashCoreTests", dependencies: ["MashCore"]),
    ]
)
