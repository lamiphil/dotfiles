#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"
WORKSPACES_DIR="$HOME/workspaces"
OBSIDIAN_CONFIG_DIR="$DOTFILES_DIR/.config/obsidian"

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BOLD="\033[1m"
RESET="\033[0m"

log_created() { echo -e "  ${GREEN}+${RESET} $1"; }
log_skipped() { echo -e "  ${YELLOW}-${RESET} $1 (already exists)"; }
log_warn()    { echo -e "  ${RED}!${RESET} $1"; }
log_header()  { echo -e "\n${BOLD}$1${RESET}"; }

create_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    log_skipped "$dir"
  else
    mkdir -p "$dir"
    log_created "$dir"
  fi
}

create_symlink() {
  local target="$1"
  local link="$2"

  if [ -L "$link" ]; then
    local current_target
    current_target=$(readlink "$link")
    if [ "$current_target" = "$target" ]; then
      log_skipped "$link -> $target"
    else
      log_warn "$link points to $current_target (expected $target) -- removing and re-creating"
      rm "$link"
      ln -s "$target" "$link"
      log_created "$link -> $target"
    fi
  elif [ -e "$link" ]; then
    log_warn "$link exists but is not a symlink -- skipping"
  else
    ln -s "$target" "$link"
    log_created "$link -> $target"
  fi
}

clone_repo() {
  local url="$1"
  local dest="$2"

  if [ -d "$dest" ]; then
    log_skipped "$dest"
  else
    echo -e "  ${GREEN}+${RESET} Cloning $url -> $dest"
    git clone "$url" "$dest"
  fi
}

generate_claude_md() {
  local workspace_dir="$1"
  local name="$2"
  local type="$3"
  local file="$workspace_dir/CLAUDE.md"
  local capitalized
  capitalized="$(echo "$name" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"

  if [ -f "$file" ]; then
    log_skipped "$file"
    return
  fi

  if [ "$type" = "work" ]; then
    cat > "$file" << EOF
# $capitalized Development Workspace

## Workspace Structure

\`\`\`
~/workspaces/$name/
├── CLAUDE.md         # This file
├── repos/            # Git repositories
├── notes/            # Obsidian vault
├── issues/           # Working directories for tasks/issues
└── tools/            # API collections and tooling
\`\`\`

### \`repos/\` — Git Repositories

All repositories are cloned here. Each is an independent git repo with its own branches, remotes, and history.

### \`notes/\` — Obsidian Vault

Notes, knowledge base, and documentation for this workspace.

### \`issues/\` — Issue Workspaces

Working directories for issues and tasks. May contain exports, scripts, notes, or any working files.

### \`tools/\` — API Collections and Tooling

Development tools and API collections for this workspace.

## Repository Map

| Repository | Path | Purpose |
|------------|------|---------|
| | \`repos/\` | |

## Security

- Never commit secrets, credentials, or API keys
- Be cautious with \`.env\` files, \`credentials.json\`, or similar sensitive files
EOF
  else
    cat > "$file" << EOF
# $capitalized Workspace

## Workspace Structure

\`\`\`
~/workspaces/$name/
├── CLAUDE.md         # This file
├── repos/            # Git repositories
│   └── portfolio/    # Personal portfolio
└── notes/            # Obsidian vault (cloned from GitHub)
\`\`\`

### \`repos/\` — Git Repositories

All repositories are cloned here. Each is an independent git repo with its own branches, remotes, and history.

### \`notes/\` — Obsidian Vault

Personal notes repository, cloned from GitHub. This is a git repo — changes should be committed and pushed.

## Repository Map

| Repository | Path | Purpose |
|------------|------|---------|
| **portfolio** | \`repos/portfolio/\` | Personal portfolio |

## Security

- Never commit secrets, credentials, or API keys
- Be cautious with \`.env\` files, \`credentials.json\`, or similar sensitive files
EOF
  fi

  log_created "$file"
}

# --- Interactive prompts ---

echo -e "${BOLD}Workspace Setup${RESET}"
echo

read -rp "Workspace name: " WORKSPACE_NAME

if [ -z "$WORKSPACE_NAME" ]; then
  echo -e "${RED}Error: workspace name cannot be empty.${RESET}"
  exit 1
fi

echo
echo "Workspace type:"
echo "  1) work     - empty notes folder, issues/ and tools/ directories, CLAUDE.md template"
echo "  2) personal - clones notes and portfolio repos from GitHub"
echo
read -rp "Select type [1/2]: " TYPE_CHOICE

case "$TYPE_CHOICE" in
  1|work)    WORKSPACE_TYPE="work" ;;
  2|personal) WORKSPACE_TYPE="personal" ;;
  *)
    echo -e "${RED}Error: invalid selection. Choose 1 or 2.${RESET}"
    exit 1
    ;;
esac

WORKSPACE_DIR="$WORKSPACES_DIR/$WORKSPACE_NAME"

echo
echo -e "${BOLD}Creating ${WORKSPACE_TYPE} workspace:${RESET} $WORKSPACE_DIR"

# --- Common structure ---

log_header "Directories"
create_dir "$WORKSPACE_DIR"
create_dir "$WORKSPACE_DIR/repos"

if [ "$WORKSPACE_TYPE" = "personal" ]; then
  log_header "Notes (cloning repo)"
  clone_repo "git@github.com:lamiphil/notes.git" "$WORKSPACE_DIR/notes"
else
  create_dir "$WORKSPACE_DIR/notes"
fi

log_header "Obsidian symlinks"
create_symlink "$OBSIDIAN_CONFIG_DIR/.obsidian" "$WORKSPACE_DIR/notes/.obsidian"
create_symlink "$OBSIDIAN_CONFIG_DIR/_config" "$WORKSPACE_DIR/notes/_config"

log_header "CLAUDE.md"
generate_claude_md "$WORKSPACE_DIR" "$WORKSPACE_NAME" "$WORKSPACE_TYPE"

# --- Type-specific steps ---

if [ "$WORKSPACE_TYPE" = "work" ]; then
  log_header "Work extras"
  create_dir "$WORKSPACE_DIR/issues"
  create_dir "$WORKSPACE_DIR/tools"
fi

if [ "$WORKSPACE_TYPE" = "personal" ]; then
  log_header "Personal repos"
  clone_repo "git@github.com:lamiphil/portfolio.git" "$WORKSPACE_DIR/repos/portfolio"
fi

echo
echo -e "${GREEN}Done.${RESET} Workspace ready at $WORKSPACE_DIR"
