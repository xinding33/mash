import Foundation
import Testing
@testable import MashCore

/// Tests write agents to a temporary folder, never ~/Library/LaunchAgents.
@Suite final class LaunchAgentTests {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    deinit { try? FileManager.default.removeItem(at: folder) }

    @Test func opensThisCopyAtLogin() throws {
        let agent = LaunchAgent(label: "test.mash", directory: folder)
        #expect(!agent.exists)
        try agent.write(executable: "/Applications/Mash.app/Contents/MacOS/Mash")
        #expect(agent.exists)
        let plist = try #require(NSDictionary(contentsOf: agent.url))
        #expect(plist["Label"] as? String == "test.mash")
        #expect(plist["ProgramArguments"] as? [String] == ["/Applications/Mash.app/Contents/MacOS/Mash"])
        #expect(plist["RunAtLoad"] as? Bool == true)
        #expect(plist["KeepAlive"] == nil)
        try agent.remove()
        #expect(!agent.exists)
    }

    @Test func restartsAfterACrashOnlyWhenAsked() {
        let plist = LaunchAgent(label: "test.mash", restartsAfterCrash: true, directory: folder).propertyList(executable: "/x")
        #expect(plist["KeepAlive"] as? [String: Bool] == ["SuccessfulExit": false])
    }

    @Test func refusesTemporaryAndBareCopies() {
        #expect(LaunchAgent.problem(bundlePath: "/Applications/Mash.app") == nil)
        #expect(LaunchAgent.problem(bundlePath: "/private/var/folders/x/AppTranslocation/y/d/Mash.app") != nil)
        #expect(LaunchAgent.problem(bundlePath: "/Users/x/code/mash/.build/release") != nil)
    }
}
