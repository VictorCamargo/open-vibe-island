import Foundation
import Testing
@testable import OpenIslandCore

struct CodexHooksTests {
    @Test
    func codexDefaultJumpTargetForwardsWarpPaneUUID() {
        var payload = CodexHookPayload(
            cwd: "/tmp/demo",
            hookEventName: .sessionStart,
            model: "gpt-4o",
            permissionMode: .default,
            sessionID: "s1",
            transcriptPath: nil
        )
        payload.terminalApp = "Warp"
        payload.warpPaneUUID = "D1A5DF3027E44FC080FE2656FAF2BA2E"
        #expect(payload.defaultJumpTarget.warpPaneUUID == "D1A5DF3027E44FC080FE2656FAF2BA2E")
    }

    @Test
    func codexWithRuntimeContextPopulatesWarpPaneUUIDFromResolver() {
        let payload = CodexHookPayload(
            cwd: "/Users/u/demo",
            hookEventName: .sessionStart,
            model: "gpt-4o",
            permissionMode: .default,
            sessionID: "s1",
            transcriptPath: nil
        ).withRuntimeContext(
            environment: ["WARP_IS_LOCAL_SHELL_SESSION": "1"],
            currentTTYProvider: { nil },
            terminalLocatorProvider: { _ in (sessionID: nil, tty: nil, title: nil) },
            warpPaneResolver: { cwd in
                cwd == "/Users/u/demo" ? "DEADBEEFDEADBEEFDEADBEEFDEADBEEF" : nil
            }
        )

        #expect(payload.terminalApp == "Warp")
        #expect(payload.warpPaneUUID == "DEADBEEFDEADBEEFDEADBEEFDEADBEEF")
        #expect(payload.defaultJumpTarget.warpPaneUUID == "DEADBEEFDEADBEEFDEADBEEFDEADBEEF")
    }

    @Test
    func codexWithRuntimeContextSkipsWarpResolverForNonWarpTerminal() {
        var resolverCalls = 0
        let payload = CodexHookPayload(
            cwd: "/Users/u/demo",
            hookEventName: .sessionStart,
            model: "gpt-4o",
            permissionMode: .default,
            sessionID: "s1",
            transcriptPath: nil
        ).withRuntimeContext(
            environment: ["TERM_PROGRAM": "ghostty"],
            currentTTYProvider: { nil },
            terminalLocatorProvider: { _ in (sessionID: nil, tty: nil, title: nil) },
            warpPaneResolver: { _ in
                resolverCalls += 1
                return "SHOULD-NOT-BE-USED"
            }
        )

        #expect(payload.terminalApp == "Ghostty")
        #expect(payload.warpPaneUUID == nil)
        #expect(resolverCalls == 0)
    }

    @Test
    func codexWithRuntimeContextDetectsCodexDesktopApp() {
        let payload = CodexHookPayload(
            cwd: "/Users/u/project",
            hookEventName: .sessionStart,
            model: "gpt-4o",
            permissionMode: .default,
            sessionID: "s1",
            transcriptPath: nil
        ).withRuntimeContext(
            environment: ["__CFBundleIdentifier": "com.openai.codex"],
            currentTTYProvider: { nil },
            terminalLocatorProvider: { _ in (sessionID: nil, tty: nil, title: nil) },
            warpPaneResolver: { _ in nil }
        )

        #expect(payload.terminalApp == "Codex.app")
        #expect(payload.warpPaneUUID == nil)
    }

    @Test
    func codexWithRuntimeContextDetectsGitHubCopilotApp() {
        let payload = CodexHookPayload(
            cwd: "/Users/u/project",
            hookEventName: .sessionStart,
            model: "gpt-4o",
            permissionMode: .default,
            sessionID: "s1",
            transcriptPath: nil
        ).withRuntimeContext(
            environment: ["__CFBundleIdentifier": "com.github.githubapp"],
            currentTTYProvider: { nil },
            terminalLocatorProvider: { _ in (sessionID: nil, tty: nil, title: nil) },
            warpPaneResolver: { _ in nil }
        )

        #expect(payload.terminalApp == "GitHub Copilot")
        #expect(payload.agentTool == .copilotCLI)
        #expect(payload.defaultJumpTarget.terminalApp == "GitHub Copilot")
    }

    @Test
    func codexWithRuntimeContextFallsBackToProcessTreeTerminalApp() {
        let payload = CodexHookPayload(
            cwd: "/Users/u/project",
            hookEventName: .userPromptSubmit,
            model: "gpt-4o",
            permissionMode: .default,
            sessionID: "s1",
            transcriptPath: nil
        ).withRuntimeContext(
            environment: [:],
            currentTTYProvider: { nil },
            terminalLocatorProvider: { terminalApp in
                #expect(terminalApp == "Ghostty")
                return (sessionID: "42", tty: nil, title: "copilot ~/project")
            },
            warpPaneResolver: { _ in nil },
            processTreeTerminalAppProvider: { "Ghostty" }
        )

        #expect(payload.terminalApp == "Ghostty")
        #expect(payload.terminalSessionID == "42")
        #expect(payload.terminalTitle == "copilot ~/project")
    }

    @Test
    func copilotSessionTitleUsesPromptWhenAvailable() {
        var payload = CodexHookPayload(
            cwd: "/Users/u/project",
            hookEventName: .userPromptSubmit,
            model: "unknown",
            permissionMode: .default,
            sessionID: "bbd19fd0-87da-47d0-b3dd-974",
            transcriptPath: nil,
            source: "copilot",
            prompt: "Fix the crash on startup"
        )
        payload.terminalApp = "Ghostty"

        #expect(payload.sessionTitle == "Fix the crash on startup")
        #expect(payload.agentDisplayName == "Copilot")
    }

    @Test
    func copilotSessionTitlePrefersConversationTitle() throws {
        let data = """
        {
          "cwd": "/Users/u/project",
          "hook_event_name": "UserPromptSubmit",
          "model": "unknown",
          "permission_mode": "default",
          "session_id": "bbd19fd0-87da-47d0-b3dd-974dca1f0000",
          "source": "copilot",
          "conversation_title": "Validar ideia de notificações do Cop",
          "prompt": "oi"
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(CodexHookPayload.self, from: data)

        #expect(payload.friendlyConversationTitle == "Validar ideia de notificações do Cop")
        #expect(payload.sessionTitle == "Validar ideia de notificações do Cop")
    }

    @Test
    func codexPermissionRequestPayloadAcceptsDescriptionOnlyToolInput() throws {
        let data = """
        {
          "cwd": "/tmp/demo",
          "hook_event_name": "PermissionRequest",
          "model": "gpt-5-codex",
          "permission_mode": "default",
          "session_id": "s1",
          "tool_name": "apply_patch",
          "tool_input": {
            "description": "Apply a focused patch to Sources/App.swift",
            "path": "Sources/App.swift"
          },
          "transcript_path": null,
          "turn_id": "turn-1"
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(CodexHookPayload.self, from: data)

        #expect(payload.hookEventName == .permissionRequest)
        #expect(payload.toolInput?.command == nil)
        #expect(payload.toolInput?.description == "Apply a focused patch to Sources/App.swift")
        #expect(payload.permissionRequestTitle == "Apply code patch")
        #expect(payload.permissionRequestSummary == "Apply a focused patch to Sources/App.swift")
    }

    @Test
    func copilotNotificationPayloadDecodesElicitationDialog() throws {
        let data = """
        {
          "cwd": "/Users/u/project",
          "hook_event_name": "Notification",
          "model": "unknown",
          "permission_mode": "default",
          "session_id": "copilot-1",
          "source": "copilot",
          "notification_type": "elicitation_dialog",
          "title": "Asking user",
          "message": "What programming language do you want to use?"
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(CodexHookPayload.self, from: data)

        #expect(payload.hookEventName == .notification)
        #expect(payload.agentTool == .copilotCLI)
        #expect(payload.notificationType == "elicitation_dialog")
        #expect(payload.notificationTitle == "Asking user")
        #expect(payload.notificationMessage == "What programming language do you want to use?")
    }

    @Test
    func copilotGhosttyNotificationUsesFocusedTerminalLocator() {
        let payload = CodexHookPayload(
            cwd: "/Users/u/project",
            hookEventName: .notification,
            model: "unknown",
            permissionMode: .default,
            sessionID: "copilot-1",
            terminalApp: "Ghostty",
            transcriptPath: nil,
            source: "copilot",
            notificationType: "elicitation_dialog",
            notificationMessage: "What programming language do you want to use?"
        ).withRuntimeContext(
            environment: ["TERM_PROGRAM": "ghostty"],
            currentTTYProvider: { nil },
            terminalLocatorProvider: { terminalApp in
                #expect(terminalApp == "Ghostty")
                return (sessionID: "ghostty-terminal-1", tty: nil, title: "GitHub Copilot")
            },
            warpPaneResolver: { _ in nil }
        )

        #expect(payload.terminalSessionID == "ghostty-terminal-1")
        #expect(payload.terminalTitle == "GitHub Copilot")
    }

    @Test
    func codexHookOutputEncoderEncodesPermissionRequestAllowDecision() throws {
        let output = try CodexHookOutputEncoder.standardOutput(
            for: .codexHookDirective(.permissionRequest(.allow))
        )

        let payload = try #require(output)
        let object = try jsonObject(from: payload)
        let hookSpecificOutput = object["hookSpecificOutput"] as? [String: Any]
        let decision = hookSpecificOutput?["decision"] as? [String: Any]

        #expect(object["continue"] as? Bool == true)
        #expect(hookSpecificOutput?["hookEventName"] as? String == "PermissionRequest")
        #expect(decision?["behavior"] as? String == "allow")
    }

    @Test
    func codexHookOutputEncoderEncodesPermissionRequestDenyDecision() throws {
        let output = try CodexHookOutputEncoder.standardOutput(
            for: .codexHookDirective(.permissionRequest(.deny(message: "Use a narrower patch.")))
        )

        let payload = try #require(output)
        let object = try jsonObject(from: payload)
        let hookSpecificOutput = object["hookSpecificOutput"] as? [String: Any]
        let decision = hookSpecificOutput?["decision"] as? [String: Any]

        #expect(hookSpecificOutput?["hookEventName"] as? String == "PermissionRequest")
        #expect(decision?["behavior"] as? String == "deny")
        #expect(decision?["message"] as? String == "Use a narrower patch.")
    }

}

private func jsonObject(from data: Data) throws -> [String: Any] {
    let object = try JSONSerialization.jsonObject(with: data)
    return object as? [String: Any] ?? [:]
}
