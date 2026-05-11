# Changelog

## [Unreleased]

### Added
- `brain-init` Step 10 now writes a vault-level `.claude/settings.local.json` with broad `Read`/`Write`/`Edit` permissions for `${vault_root}/**` and `Bash` permissions for the plugin's scripts and hooks. Future sessions working inside the vault auto-allow file operations without per-write prompting.
- brain-init also ensures `.claude/settings.local.json` is gitignored at the vault root so machine-local permissions don't leak across machines.

### Changed
- brain-init step numbering: previous Step 10 (Git commit) → Step 11, previous Step 11 (Print summary) → Step 12.
- **Skills do not run git commands against the vault.** The vault owns its own git lifecycle, managed externally to any Claude Code session (periodic auto-commit, an external coordinator agent, or user-managed — the mechanism varies). Removed `dev-log write` Step 8 git commit/push, removed `workspaces create` git tip output, and rewrote `brain-init` Step 11 to make this explicit. `partner-model` SKILL.md "What NOT to do" gains an entry to match.

## [0.1.1] - 2026-05-11

### Fixed
- Plugin manifest moved from repo root to canonical `.claude-plugin/plugin.json`. v0.1.0 was non-discoverable as a Claude Code plugin because the manifest was in the wrong location.

### Added
- `SessionStart` hook (`hooks/session-start.sh`) auto-loads the partner-model file into session context. Resolves paths via the same three-tier logic as the partner-model skill (env var → `.vault.toml` → default). Silent no-op in non-brain-kit contexts.
- `templates/minimal/persona.md` — frontmatter-less persona template for minimal mode.
- `skills/brain-init/references/persona-interview.md` — 5-question persona interview, conducted by brain-init to populate `me.md`.

### Changed
- `author` field reformatted to object form (`{name, email}`) per plugin manifest convention.
- Persona/partner-model layer separation clarified across SKILL files and reference docs. The persona interview now builds `me.md` (declared facts). The partner-model bootstrap derives **inferred observations** from the persona (and optionally from Claude Code conversation logs, v0.2) — never asks the user about preferences.
- `seed-prompts.md` renamed to `seed-sources.md` and rewritten as a sourcing-model reference.
- `partner-model` SKILL.md updated to reflect SessionStart auto-load (no longer manual-load).

## [0.1.0] - 2026-05-11
### Added
- Initial plugin scaffold
- partner-model skill (with bootstrap + consolidate subcommands)
- workspaces skill (mini-vault contract create + maintain)
- dev-log skill (init + write)
- brain-init skill (bootstrap a vault)
- .vault.toml config layer with auto-discovery
- Minimal and strict modes with structured-mode templates
