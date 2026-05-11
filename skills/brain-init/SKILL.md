---
name: brain-init
description: Bootstrap brain-kit in a new vault directory. Use when the user says "brain-init", "set up brain-kit here", "initialize a vault", or invokes the skill explicitly. Greenfield only — no-op if .vault.toml already exists in CWD or any parent. Sets up vault config, folder skeleton, optional persona seed, and partner-model bootstrap.
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion]
---

# brain-init

## Overview

brain-init is the greenfield-only orchestrator that initializes a brain-kit vault in the current directory. It asks the user about mode and config, copies templates, creates the folder skeleton, and optionally seeds the partner model. The skill is intentionally idempotent: it aborts cleanly if a `.vault.toml` is already discoverable at or above CWD, so running it twice or in an already-initialized vault is always safe. It calls other brain-kit skills for behavioral work (partner-model bootstrap) rather than reimplementing them.

## When to use

- User explicitly says "brain-init", "set up brain-kit here", or "initialize a vault"
- User invokes `/brain-init` as a slash command
- **Not** auto-triggered on session start — always explicit
- **Greenfield only** — aborts if `.vault.toml` already exists at or above CWD

---

## Step 1: Idempotency check

Run:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/detect-vault-config.sh "$PWD"
```

If this exits 0 (a `.vault.toml` is found at CWD or any parent), abort immediately with:

```
Vault already initialized at {found_path}.
Use /brain-init only in fresh directories.
```

Exit cleanly. Do NOT overwrite or modify the existing setup. Do not proceed to any subsequent step.

---

## Step 2: Choose mode

Use AskUserQuestion to ask the user which mode they want:

- **strict (recommended)** — typed-note ontology. Enforces typed notes, required frontmatter, and template discipline. Use if you want full typed-note rigor and structured-vault compatibility.
- **minimal** — loose conventions, no required frontmatter. Use for lightweight personal setups or experimentation.

Default to **strict** if the user provides no answer.

---

## Step 3: Choose vault root

Ask the user:

> Vault root path (relative to current directory)?

Default: `.` (the current directory).

Validate: the path must either already exist or be creatable as a directory. If it doesn't exist, confirm with the user before creating it.

---

## Step 4: Profile name

Ask the user:

> Profile name (e.g., work, personal, default)?

Default: `default`.

This value is substituted into the vault config as the partner model profile identifier.

---

## Step 5: Persona seed

Ask the user how they want to populate the **persona file** (`me.md`) — the declared-facts-about-you note that the partner-model bootstrap later derives observations from:

> Set up your persona? Choices:
> - **Build new via interview** (recommended) — short conversational interview (~5 questions about who you are, what you're working on, who you work with, what you're growing in). The answers populate `me.md` directly.
> - **Use an existing persona file** — point to a note you've already written elsewhere; we'll copy or symlink it into place.
> - **Skip** — no persona file. The partner model will start empty and populate via real session observations only.

Default: **Build new via interview**.

The interview builds the **persona layer** (declared facts about the user). The partner-model bootstrap later reads the persona and derives **observations** from it — that's a separate step in Step 9. See `references/persona-interview.md` for the interview questions and `skills/partner-model/references/seed-sources.md` for how the persona becomes seed observations.

Record the user's choice. Do not take action yet — persona work happens in Step 9.

---

## Step 6: Copy vault config

- Source: `${CLAUDE_PLUGIN_ROOT}/templates/{mode}/vault.toml`
- Destination: `${vault_root}/.vault.toml`
- After copying, substitute the profile name into the `[partner_model]` section: `profile = "{profile}"`

Defensive check: if `.vault.toml` already exists at the destination (shouldn't happen given Step 1, but be cautious), abort:

```
Unexpected: .vault.toml already exists at {vault_root}/.vault.toml.
Aborting to avoid overwrite.
```

Do not proceed if the file is already present.

---

## Step 7: Create folder skeleton

Read the resolved config values from the newly placed `.vault.toml` to determine directory names. Then create the following directories with `mkdir -p` (safe — no overwrite of existing content):

**All modes:**
- `${vault_root}/${workspaces_dir}/`
- `${vault_root}/${notes_dir}/`
- `${vault_root}/${logs_dir}/`

**Strict mode additionally:**
- `${vault_root}/${journal_dir}/`
- `${vault_root}/${system_dir}/`
- `${vault_root}/${system_dir}/logs/`
- `${vault_root}/${system_dir}/Templates/`

---

## Step 8: Strict-mode template installation

If the user chose **strict mode**, copy the following template files. All go into `${vault_root}/${system_dir}/Templates/`:

| Source | Destination filename |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/templates/strict/_note.md` | `_note.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/strict/_task.md` | `_task.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/strict/_daily.md` | `_daily.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/strict/_meeting.md` | `_meeting.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/strict/persona.md` | `_persona.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/strict/log.md` | `_log.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/strict/workspace.md` | `_workspace.md` |

Do **not** copy `vault.toml` here — that is the config file already placed in Step 6.

Skip this step entirely for minimal mode.

---

## Step 9: Persona seed (if requested)

Take action based on the choice from Step 5:

**Build new via interview:**

Conduct the persona interview per `references/persona-interview.md`. Ask the questions one at a time via `AskUserQuestion` (conversational, not form-like). Assemble the answers into a persona file at the path resolved by `persona.path` in `.vault.toml` (default `${vault_root}/Notes/me.md`).

For **strict mode**, the persona file uses the typed-note frontmatter from `${vault_root}/${system_dir}/Templates/_persona.md` (`type: note, kind: persona, title:`, etc.). Fill `title:` with the user's name (ask if not obvious), set `created` and `modified` to the current ISO 8601 timestamp.

For **minimal mode**, use the frontmatter-less template at `${CLAUDE_PLUGIN_ROOT}/templates/minimal/persona.md` — just section headers, no YAML.

After the persona file is written, invoke `/partner-model bootstrap`. The bootstrap will detect the new persona and derive observations from it.

**Use an existing persona file:**

Ask the user for the path to their existing persona note. Copy or symlink it to the path resolved by `persona.path` (default `${vault_root}/Notes/me.md`). Then invoke `/partner-model bootstrap` — it will detect the persona and derive observations from it.

**Skip:**

Create an empty model file at the resolved partner-model path with minimal content:

```
---
---
```

Also touch the partner-model log file at the resolved log path so future consolidation has a target to append to. No persona file is created; the partner model populates via real session observations only.

---

## Step 10: Write vault permissions

Create `${vault_root}/.claude/settings.local.json` so future sessions working inside the vault auto-allow file operations without prompting per write. If the file already exists with other permissions, **merge** — add the brain-kit entries without removing existing ones.

```bash
mkdir -p "${vault_root}/.claude"
```

Content (substitute the resolved absolute `${vault_root}` everywhere):

```json
{
  "permissions": {
    "allow": [
      "Read(${vault_root}/**)",
      "Write(${vault_root}/**)",
      "Edit(${vault_root}/**)",
      "Bash(*/brain-kit/scripts/*.sh:*)",
      "Bash(*/brain-kit/hooks/*.sh:*)"
    ]
  }
}
```

The wildcards on the Bash entries cover both symlinked installs (`~/.claude/plugins/brain-kit/scripts/...`) and cached marketplace installs (`~/.claude/plugins/cache/.../brain-kit/scripts/...`).

This grants broad vault file access. The user can tighten later by replacing `**` globs with narrower paths if desired.

Also create a shared `${vault_root}/.claude/settings.json` (committed if vault is git-backed) containing only the SessionStart hook reference — atlas's pattern is to keep hooks in `settings.json` (shared) and permissions in `settings.local.json` (machine-local). For v0.1.x brain-kit relies on the plugin-level SessionStart hook, so `settings.json` here is optional; skip if not needed.

Add `.claude/settings.local.json` to `${vault_root}/.gitignore` (create it if missing) so machine-local permissions don't leak across machines.

---

## Step 11: Git (do not commit)

**Do not run any git commands against the vault.** The vault owns its own git lifecycle.

If the vault has SessionStart commit hooks (atlas-style: a hook that snapshots and pushes the vault at session boundaries), they will pick up the newly created vault structure automatically. If the vault has no such automation yet, the user will set it up or commit manually — that's their call.

This skill's job ends when the files are written. Print to the user a one-line note that the vault now has new contents, and if it's a git repo and they want automatic versioning, they may want to add a SessionStart commit hook. Do not show a `git add` command.

---

## Step 12: Print summary

After all steps complete, print:

```
✓ brain-kit initialized
  Mode: {mode}
  Vault root: {vault_root}
  Config: {vault_root}/.vault.toml
  Workspaces: {vault_root}/${workspaces_dir}/
  Logs: {vault_root}/${logs_dir}/
  Profile: {profile}
  Partner model: {seeded|empty}

Next steps:
  1. Create your first workspace: /workspaces create
  2. Write your first session log when you finish a task: /devlog write
  3. Optionally edit your persona: ${vault_root}/Notes/me.md
```

---

## Confirmation requirements

Always confirm with the user before:

- Overwriting any existing file (shouldn't happen given the Step 1 and Step 6 checks, but be defensive)
- Running partner-model bootstrap (the user opted in during Step 5, but confirm once more before invoking)

Do **not** auto-commit git history. Step 10 is always a suggestion, never automatic.

---

## What NOT to do

- Don't run if any `.vault.toml` already exists at or above CWD — the idempotency check in Step 1 is non-negotiable
- Don't copy templates outside `${vault_root}/${system_dir}/Templates/`
- Don't auto-create workspaces — that is the workspaces skill's job (`/workspaces create`)
- Don't push or amend git history
- Don't reimplement partner-model bootstrap logic — call `/partner-model bootstrap` and let it handle the seeding from persona
