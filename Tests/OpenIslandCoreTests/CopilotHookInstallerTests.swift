import Foundation
import Testing
@testable import OpenIslandCore

struct CopilotHookInstallerTests {
    @Test
    func hooksJSONUsesCopilotSourceAndCompatibleEventNames() throws {
        let command = CopilotHookInstaller.hookCommand(for: "/tmp/OpenIslandHooks")
        let data = try CopilotHookInstaller.hooksJSON(hookCommand: command)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let hooks = try #require(root["hooks"] as? [String: [[String: Any]]])

        #expect(command == "'/tmp/OpenIslandHooks' --source copilot")
        #expect(Set(hooks.keys) == ["SessionStart", "UserPromptSubmit", "PermissionRequest", "Notification", "Stop"])
        #expect(hooks["Stop"]?.first?["command"] as? String == command)
        #expect(hooks["Notification"]?.first?["command"] as? String == command)
        #expect(hooks["PermissionRequest"]?.first?["timeoutSec"] as? Int == 600)
    }
}
