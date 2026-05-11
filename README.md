# brain-kit

> Portable second-brain skills for Claude Code. Two-mode, vault-aware, structured-vault-compatible.

## What is brain-kit?

brain-kit packages a set of skills that let Claude Code build and maintain a personal knowledge layer in any markdown vault: a behavioral model of you (partner-model), a workspace contract (mini-vaults for each project), session dev logs, and a one-shot vault initializer (brain-init). It's a portable, reusable set of patterns that work in any markdown directory.

## Why

- Personal context that survives across sessions, not just within
- Project structure that AI agents can navigate without rediscovery each session
- Persistent dev logs that capture *why*, not just *what* (read by future agents)
- Behavioral patterns observed once, applied always
- Vault-agnostic: works in any markdown directory, not tied to one tool

## Two modes

- **Minimal** — loose conventions, no frontmatter requirements. Get going fast.
- **Strict** — typed-note ontology with `type:`/`kind:` frontmatter. Use when you want full structure or interop with structured-vault tooling.

Mode is chosen at init time and recorded in `.vault.toml`.

## Skills

| Skill | Purpose | Subcommands |
|---|---|---|
| `partner-model` | Maintains a behavioral model of you | `bootstrap`, `consolidate` |
| `workspaces` | Create + audit mini-vault workspaces | `create`, audit on existing |
| `dev-log` | Session log writing + workspace integration | `init`, `write` |
| `brain-init` | One-shot vault setup for a fresh directory | (none — single command) |

## Install

```bash
git clone git@github.com:dbtlr/brain-kit.git ~/workspaces/brain-kit
ln -s ~/workspaces/brain-kit ~/.claude/plugins/brain-kit
```

Verify:

```bash
ls ~/.claude/plugins/brain-kit/plugin.json
```

## Quick start

In Claude Code, from your vault directory:

```
/brain-init           # bootstrap the vault (asks mode, profile, persona)
/workspaces create    # add your first workspace (asks name)
/devlog write         # write your first session log
```

## Documentation

Each topic has a dedicated reference:

- [bootstrapping.md](references/bootstrapping.md) — full setup guide, troubleshooting
- [vault-config.md](references/vault-config.md) — `.vault.toml` field-by-field
- [workspace-contract.md](references/workspace-contract.md) — mini-vault structure
- [partner-model-schema.md](references/partner-model-schema.md) — log + model schemas
- [strict-mode-ontology.md](references/strict-mode-ontology.md) — typed-note ontology

## Status

> **v0.1.0 — pre-1.0, breaking changes possible.** Ships as a working pilot. APIs and config schema may shift before v1.0.

## Optional dependencies

For schema validation (`scripts/validate-vault-config.sh`):

- `dasel` — TOML→JSON converter
- `ajv-cli` — JSON Schema validator

Without these, validation is skipped silently. brain-kit works fine without them.

## Origin

brain-kit extracts and generalizes the partner-model, mini-vault workspaces, and dev-log patterns from a personal Obsidian vault running this stack natively. The inline versions predate brain-kit; migration to the portable plugin form is planned for a later release once the pilot validates the portable design.

## Contributing

Pre-1.0 means breaking changes happen. File issues at github.com/dbtlr/brain-kit/issues. PRs welcome but ping first if scope is non-trivial.

## License

MIT — see plugin.json author field for contact.
