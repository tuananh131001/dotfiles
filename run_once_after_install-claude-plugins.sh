#!/usr/bin/env bash
# Register the agent-expert marketplace and install its plugin in Claude Code.
set -euo pipefail
command -v claude >/dev/null || exit 0
claude plugin marketplace add tuananh131001/agent-expert || true
claude plugin install agent-expert@agent-expert || true
