#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

"$repo_root/scripts/launch-dev-app.sh" --skip-setup

cat <<'EOF'

Open Island Dev was installed to ~/Applications/Open Island Dev.app and opened.

Hooks were not installed by this script.
To enable Copilot CLI notifications:
1. Open Open Island settings.
2. Go to Setup.
3. Click Install on the Copilot CLI row.

EOF
