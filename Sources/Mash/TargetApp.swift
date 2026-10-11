import AppKit

/// The app Mash presses its key in.
struct TargetApp: Codable, Hashable {
    var bundleID: String
    var name: String

    static let geforceNow = TargetApp(bundleID: "com.nvidia.gfnpc.mall", name: "NVIDIA GeForce NOW")

    var isFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID
    }
}

extension TargetApp {
    init?(bundleURL: URL) {
        guard let bundle = Bundle(url: bundleURL), let bundleID = bundle.bundleIdentifier else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundleURL.deletingPathExtension().lastPathComponent
        self.init(bundleID: bundleID, name: name)
    }
}
