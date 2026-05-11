# Bootstrapping brain-kit

This guide walks you through setting up brain-kit from scratch — installing the plugin, initializing a vault, and getting your first workspace and dev log running.

---

## Prerequisites

- **Claude Code** installed and working (`claude --version`)
- **A directory** that will become your vault — can be empty or existing; brain-kit doesn't touch files it doesn't know about
- **Optional:** `dasel` and `ajv-cli` for `.vault.toml` schema validation via `scripts/validate-vault-config.sh`

---

## 1. Install brain-kit

Clone or fork the repo into your dotfiles or workspaces directory:

```bash
git clone https://github.com/your-fork/brain-kit.git ~/dotfiles/brain-kit
# or wherever you keep plugins/dotfiles
```

Symlink it into Claude Code's plugin directory:

```bash
mkdir -p ~/.claude/plugins
ln -s ~/dotfiles/brain-kit ~/.claude/plugins/brain-kit
```

Verify the symlink is correct:

```bash
ls ~/.claude/plugins/brain-kit/plugin.json
```

You should see the file, not an error. If you get "no such file or directory", the symlink target path is wrong — double-check the source path.

---

## 2. Initialize a vault

`cd` into the directory that will be your vault:

```bash
cd ~/my-vault   # or wherever your vault will live
```

Open Claude Code in that directory, then invoke the init skill:

```
/brain-init
```

The skill will ask you three questions:

**Mode:** Choose `strict` (recommended) or `minimal`.
- Strict enforces the typed-note ontology — typed frontmatter, structured templates. Use this if you want full structure or plan to use structured-vault tooling.
- Minimal enforces only the structural layout — no frontmatter required. Use this for a lightweight setup.

See [strict-mode-ontology.md](strict-mode-ontology.md) for what strict mode adds, and [vault-config.md](vault-config.md) for the `mode.strict` config key.

**Profile name:** A context identifier for your partner model (`work`, `personal`, `default`). If you only have one vault, use `default`. If you maintain separate vaults for work and personal use, name them accordingly — each profile gets its own consolidated model file.

**Partner model seed:** How to initialize the partner model:
- **Run interview** (default) — 5-question behavioral interview that seeds initial observations
- **From persona file** — point to an existing persona note to seed from
- **Skip** — start with an empty model and populate it through normal sessions

After completing the questions, brain-init creates:
- `.vault.toml` in the vault root
- `Workspaces/`, `Notes/`, `Log/` directories (plus `Journal/`, `System/`, `System/Templates/` in strict mode)
- The partner model file and log file
- In strict mode: typed templates in `System/Templates/`

---

## 3. Create your first workspace

A workspace is how you organize a project inside the vault. Invoke:

```
/workspaces create
```

The skill will ask for a workspace name (use kebab-case: `my-project`, not `MyProject` or `my_project`). It scaffolds the directory structure and canonical note, then asks you to confirm.

Once created, open `Workspaces/my-project/my-project.md` and fill in the **above-the-rule** section — the project description, tech stack, key paths, and any navigation links you want. The below-the-rule sections are managed by `/devlog write` and will fill in over time.

See [workspace-contract.md](workspace-contract.md) for the full structure and above/below-the-rule semantics.

---

## 4. Write your first dev log

After completing a task or wrapping up a session, invoke:

```
/devlog write
```

The skill reviews what happened in the session and writes a log entry to `Log/`. It also updates the below-the-rule sections of your workspace's canonical note with current state, next steps, open questions, and recent session notes.

Dev logs are the primary way the workspace note stays fresh across sessions. Run it at the end of any session where you made progress.

---

## 5. Periodic consolidation

The partner model grows over time as sessions add observation entries to the JSONL log. Periodically — monthly, or after a significant accumulation of new observations — run:

```
/partner-model consolidate
```

This reads the full log and rewrites the consolidated model markdown file. It groups observations by theme, promotes repeated patterns, applies corrections, and drops noise. The skill prints a diff summary showing what changed.

Don't skip consolidation too long — the model degrades if it's running off a stale consolidated file while the log has grown significantly.

See [partner-model-schema.md](partner-model-schema.md) for the log entry schema and consolidation rules.

---

## Troubleshooting

**"no .vault.toml found"**

Skills couldn't find a vault config by walking up from your current directory. Run `/brain-init` from your vault root directory, or check that you're inside the vault (`ls .vault.toml` from the vault root should work). See [vault-config.md](vault-config.md) for how discovery works.

**"vault already initialized"**

`/brain-init` found an existing `.vault.toml` at or above CWD and aborted. This is correct behavior — brain-init is greenfield only. If you want to reconfigure, edit `.vault.toml` directly. Use `/workspaces create` and other skills directly.

**Permission errors writing to vault**

Check `.claude/settings.local.json` in your brain-kit directory. Pre-populated permissions may be present; you may need to add write permissions for your vault path. Specifically, `Bash(mkdir:...)`, `Write`, and `Edit` permissions for your vault root.

**Skill not triggering on `/brain-init` or other commands**

Verify the plugin is correctly symlinked:

```bash
ls ~/.claude/plugins/brain-kit/plugin.json   # should exist
ls -la ~/.claude/plugins/brain-kit            # should show symlink target
```

If the plugin directory exists but `plugin.json` is missing, the symlink target is wrong. If the symlink exists but Claude Code doesn't recognize the skill, restart Claude Code — plugin discovery happens at startup.

**Partner model not loading at session start**

The partner-model skill loads the model on session start. If it's not loading, check:
1. `.vault.toml` is discoverable from your CWD (run `scripts/detect-vault-config.sh "$PWD"`)
2. The model file exists at the resolved path (`System/partner_model.md` or the profile-adjusted name)
3. `$PARTNER_MODEL_PATH` is not set to a stale path in your shell environment

---

## Going further

Now that you have a working vault:

- **[vault-config.md](vault-config.md)** — full reference for every `.vault.toml` field
- **[workspace-contract.md](workspace-contract.md)** — the workspace directory layout and canonical note structure
- **[partner-model-schema.md](partner-model-schema.md)** — JSONL log schema and consolidated model structure
- **[strict-mode-ontology.md](strict-mode-ontology.md)** — the type/kind taxonomy and when to use each

For ongoing use, the main loop is: work in sessions → `/devlog write` at session end → `/partner-model consolidate` monthly.
