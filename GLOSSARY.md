# Dotfiles

Personal machine setup: host tool configuration deployed into `$HOME`, and the bootstrap that also sets up the agents repo.

## Repositories

**Dotfiles**:
The public repository for host tools (shell, editor, terminal, multiplexer, window managers) and the bootstrap script.
_Avoid_: config repo

**Agents repo**:
The public repository for everything that exists only because of AI agents: own skills, global instructions and agent config.
_Avoid_: skills repo, agents folder

## Agent setup

**Agent config**:
The configuration of agent tools (Pi, Claude Code, Codex, OpenCode): extensions, package patches, settings, prompts, themes and MCP servers. It lives in the agents repo.

**Global instructions**:
The one instruction file that applies to every agent session on the machine. Pi's `AGENTS.md` is the master; Claude Code and Codex point to it. It holds no tool-specific rules.
_Avoid_: global preferences, CLAUDE.md, APPEND_SYSTEM

**Repo guide**:
A repository's own description for agents. It applies only while working inside that repository and is never deployed to `$HOME`.
_Avoid_: dotfiles AGENTS.md, global AGENTS.md

**Own skill**:
A skill Philippe wrote. Only own skills are published in the agents repo.

**Vooban skill**:
An own skill that only makes sense for Vooban work. It sits in the agents repo folder but is never published, so it exists only on machines where it was copied by hand.
_Avoid_: work skill, private skill

**Third-party skill**:
A skill installed from someone else's repository. It is reinstalled from its source on a new machine, never copied into a repository.
_Avoid_: external skill, vendored skill

## Logs

**Log target**:
The one file a `/log` writes to. It comes only from a log declaration, never from guessing paths.

**Log declaration**:
A statement in an `AGENTS.md` that gives the log target (path or rule), its language and its visibility. The nearest `AGENTS.md` wins.

**Work log**:
A customer's private `_log.md` in the Vooban notes vault. All Vooban work logs here, even work done in a repository.
_Avoid_: customer log, journal

**Project log**:
A `LOG.md` at the root of one of Philippe's personal repositories. It is written for Philippe, not for the repository's users.
_Avoid_: repo log, changelog

**Public log**:
A log target declared public. Every entry follows the safety rules: no people or company names, no non-public identifiers or paths, no secrets, no private life.

## Setup

**Bootstrap script**:
The one dotfiles command that sets up a new machine: it places the host tool configuration, fetches the agents repo and runs the agent installer.
_Avoid_: setup script

**Agent installer**:
The agents repo's own setup command. It places the agent setup where each tool expects it and reinstalls third-party skills and Pi packages; it can run alone, for example after a Pi upgrade.
_Avoid_: install script
