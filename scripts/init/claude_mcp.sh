#!/bin/bash

# Re-applies user-scope MCP servers for Claude Code.
# ~/.claude.json holds conversation history and other runtime state alongside
# config, so it isn't stowed directly. Run this script instead (idempotent:
# safe to re-run any time, e.g. after cloning dotfiles on a new machine).

set -euo pipefail

command -v claude >/dev/null 2>&1 || { echo "claude CLI not found, skipping MCP setup."; exit 0; }

add_server() {
  local name="$1"
  local transport="$2"
  local url="$3"

  if claude mcp get "$name" >/dev/null 2>&1; then
    echo "✅ MCP server '$name' already configured."
  else
    echo "➕ Adding MCP server '$name'..."
    claude mcp add --transport "$transport" --scope user "$name" "$url"
  fi
}

add_server atlassian sse https://mcp.atlassian.com/v1/sse
