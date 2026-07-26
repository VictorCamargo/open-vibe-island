import Foundation

public struct CopilotHookInstallerManifest: Equatable, Codable, Sendable {
    public static let fileName = "open-island-copilot-hooks-install.json"

    public var hookCommand: String
    public var installedAt: Date

    public init(hookCommand: String, installedAt: Date = .now) {
        self.hookCommand = hookCommand
        self.installedAt = installedAt
    }
}

public enum CopilotHookInstaller {
    public static let managedHookFileName = "open-island.json"

    private static let eventSpecs: [(name: String, timeout: Int)] = [
        ("SessionStart", 45),
        ("UserPromptSubmit", 45),
        ("Stop", 45),
    ]

    public static func hookCommand(for binaryPath: String) -> String {
        "\(shellQuote(binaryPath)) --source copilot"
    }

    public static func hooksJSON(hookCommand: String) throws -> Data {
        var hooks: [String: Any] = [:]
        for spec in eventSpecs {
            hooks[spec.name] = [[
                "type": "command",
                "command": hookCommand,
                "timeoutSec": spec.timeout,
            ]]
        }

        return try JSONSerialization.data(
            withJSONObject: [
                "version": 1,
                "hooks": hooks,
            ],
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private static func shellQuote(_ string: String) -> String {
        guard !string.isEmpty else { return "''" }
        return "'\(string.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
