# AI Build and Install Notes

This fork adds Copilot CLI and GitHub Copilot.app hook support to Open Island.

## Install locally

From the repository root:

```bash
zsh scripts/install-local.sh
```

The script builds the app, installs `Open Island Dev.app` into `~/Applications`,
ad-hoc signs it if no local signing identity exists, and opens it.

It intentionally does not install any CLI hooks.

## Enable Copilot CLI hooks

After the app opens:

1. Open Open Island settings.
2. Go to the Setup tab.
3. Click `Install` on the `Copilot CLI` row.

The app writes `~/.copilot/hooks/open-island.json` only from this UI action
or from the explicit `Install All` button. The same hook path is used by
Copilot CLI and GitHub Copilot.app.

## Useful checks

```bash
swift build
swift test --filter CopilotHookInstallerTests
swift test --filter TerminalJumpServiceTests
```

If Ghostty or Terminal jump-back does not focus the right tab, check macOS
permissions:

```text
System Settings > Privacy & Security > Automation
System Settings > Privacy & Security > Accessibility
```

Allow `Open Island Dev` to control the terminal app you use.
