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

Ask the user how they want to seed the partner model:

> Seed the partner model now? Choices:
> - **From persona file** (recommended) — point to an existing persona note (you'll be asked for path). The bootstrap infers initial observations from the declared facts.
> - **Skip** — initialize an empty model and let observations accumulate through normal sessions.

Default: **From persona file** if the user mentions they have one, else **Skip**.

The partner model is observation-driven; there is no interview. See `skills/partner-model/references/seed-sources.md` for the sourcing model.

Record the user's choice. Do not take action yet — persona seeding happens in Step 9.

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

**From persona file:**
Ask the user for the path to their existing persona note. Copy or symlink it to `${vault_root}/Notes/me.md` (or wherever `persona.path` resolves in the vault config). Then invoke `/partner-model bootstrap` — it will detect the persona and derive observations from it.

**Skip:**
Create an empty model file at the resolved partner model path with minimal content:

```
---
---
```

Also touch the partner model log file at the resolved log path so future consolidation has a target to append to.

---

## Step 10: Git commit (if applicable)

Check whether `${vault_root}` is inside a git repository:

```bash
git -C "${vault_root}" rev-parse --is-inside-work-tree 2>/dev/null
```

**If inside a git repo:** Suggest the following command but do not run it automatically:

```bash
git -C ${vault_root} add .vault.toml ${workspaces_dir} ${notes_dir} ${logs_dir} && git commit -m "chore: initialize brain-kit"
```

Let the user decide whether to commit. Present it as a suggestion only.

**If not a git repo:** Skip silently.

---

## Step 11: Print summary

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
