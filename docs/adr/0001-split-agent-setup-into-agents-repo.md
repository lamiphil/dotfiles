# Split the agent setup into a separate agents repo

Everything that exists only because of AI agents (own skills, global instructions, Pi/Claude/Codex/OpenCode config) moves from dotfiles to a public `agents` repo; host tools stay in dotfiles, including host settings that merely launch agents. Skills, extensions and instructions change together almost daily and reference each other, so they share one repo, while dotfiles changes rarely.

## Considered Options

- **Skills-only repo, agent config in dotfiles**: rejected. Extensions call skills and instructions point to extensions, so most changes would need commits in two repos.
- **Git submodules from dotfiles**: rejected. Every daily skill edit would also need a pointer bump in dotfiles. The dotfiles bootstrap clones the agents repo and runs its own installer instead.
- **Separate private repo for Vooban skills**: rejected. Vooban skills stay gitignored inside the agents repo folder; they are not backed up and must be copied by hand to a new machine.

## Consequences

- The agents repo starts with a fresh history; earlier history stays in dotfiles, after the Vooban data was rewritten out of it.
- `~/.agents/skills` becomes a plain folder filled from three sources (published own skills, gitignored Vooban skills, third-party skills reinstalled from the lock file), and `~/.pi` is stowed without folding so runtime state and credentials no longer live in a repo folder.
- The master global instructions sit at `pi/agent/AGENTS.md`, not at the repo root, so they do not double as the repo guide.
