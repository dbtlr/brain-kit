---
name: workspaces
description: Create and maintain mini-vault workspaces in a brain-kit vault. Use when the user says "new workspace", "create workspace", "add workspace", or asks to organize project material into a workspace. Also runs as an audit when invoked on an existing workspace to verify mini-vault contract compliance.
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion]
---

# workspaces

## Overview

The workspaces skill manages mini-vault workspace structures inside a brain-kit vault. It supports two operations: create a new workspace following the mini-vault contract, or audit/maintain an existing one for contract compliance. The skill is mode-aware — it reads the `mode.strict` flag from `.vault.toml` and applies strict-mode rules (full frontmatter, typed subdirectory files) or minimal-mode rules (structure only, no required frontmatter) accordingly. All operations are interactive: the skill confirms before creating and reports before repairing.

## When to Use

Triggers and intents:

- "create workspace X" / "new workspace X" / "add workspace X"
- "audit workspace X" / "check workspace X" / "verify workspace X"
- User wants to organize project material into a dedicated workspace structure

## Step 1: Resolve Config

Use the same path resolution as the partner-model skill:

1. **Environment variable (highest priority):** If `$VAULT_ROOT` is set, use it as the vault root.
2. **Vault config discovery:** Invoke `${CLAUDE_PLUGIN_ROOT}/scripts/detect-vault-config.sh` with `$PWD` as the start directory. If it succeeds, parse the returned `.vault.toml` path:
   - `vault.root` — vault root directory (default: `.`, meaning the directory containing `.vault.toml`)
   - `vault.workspaces_dir` — workspace directory relative to vault root (default: `Workspaces`)
   - `mode.strict` — boolean; `true` = strict mode, `false` or absent = minimal mode
3. **Default fallback:** Use `$PWD` as vault root, `Workspaces` as workspaces_dir, minimal mode.

Derive:
- **vault root** — absolute path
- **workspaces_dir** — absolute path: `{vault_root}/{workspaces_dir}` (default `{vault_root}/Workspaces`)
- **mode** — `strict` or `minimal`

If `workspaces_dir` does not exist, abort: "no workspaces directory found at `{workspaces_dir}`. Is this a brain-kit vault?"

## Step 2: Detect Operation

Inspect the user's intent and the workspace name argument (if any):

- If user said "create", "new", or "add": **create operation** → go to Step 3a
- If workspace name argument matches an existing directory under `workspaces_dir`: **audit operation** → go to Step 3b
- If workspace name argument does NOT match an existing directory AND user did not say "create"/"new"/"add": **ambiguous** → ask: "Workspace `{name}` doesn't exist yet. Did you want to create it, or did you mean a different name?"
- If no workspace name was given: ask for it before proceeding

## Step 3a: Create Operation

### Collect and validate the workspace name

If the user typed a name, use it. Validate:
- Lowercase letters, digits, and hyphens only
- No spaces, no underscores, no uppercase
- Must not be empty

If invalid, explain the rule and ask for a corrected name. If the name passed validation but was not explicitly typed (inferred from context), confirm the name before proceeding.

### REQUIRED CONFIRMATION

**Always ask before creating.** Never create a workspace silently. Present:

```
Create new workspace `{name}` at `{workspaces_dir}/{name}/`?
Mode: {strict | minimal}
[yes/no]
```

If the user says no, stop. Do not create anything.

### Create directory structure

On confirmation, create:

```
{workspaces_dir}/{name}/
├── tasks/
├── notes/
└── agent-artifacts/
```

Use `mkdir -p` (via Bash) for each subdirectory.

### Create the canonical workspace note

Select the template based on mode:

- **Strict mode:** `${CLAUDE_PLUGIN_ROOT}/templates/strict/workspace.md`
- **Minimal mode:** `${CLAUDE_PLUGIN_ROOT}/templates/minimal/workspace.md`

Substitute template variables:
- `{{name}}` → the workspace name (kebab-case)
- `{{date}}` or `{{date:YYYY-MM-DDTHH:mm}}` → current timestamp in `YYYY-MM-DDTHH:mm` format
- In strict mode, set `title:` to the workspace name and add the name to `aliases:`

Write the result to `{workspaces_dir}/{name}/{name}.md`.

### Git

**Do not run any git commands.** The vault owns its own git lifecycle — if it has SessionStart commit hooks (atlas-style), they will pick up the new workspace at the next session boundary. If the user wants to commit manually, they will.

### Output

```
✓ Created workspace: {name}
  Root:            {workspaces_dir}/{name}/{name}.md
  Tasks:           {workspaces_dir}/{name}/tasks/
  Notes:           {workspaces_dir}/{name}/notes/
  Agent artifacts: {workspaces_dir}/{name}/agent-artifacts/

Next: edit the canonical note's above-the-rule sections to capture tech stack, key paths, conventions.
```

## Step 3b: Maintain / Audit Operation

### Load the canonical note

Read `{workspaces_dir}/{name}/{name}.md`. If it does not exist, abort:

```
No canonical note found at `{workspaces_dir}/{name}/{name}.md`.
Did you mean to create this workspace? Run: /workspaces create {name}
```

### Run contract checks

Check each item from `references/contract.md`. Report pass/fail for each.

**Both modes — required checks:**

1. `tasks/` directory exists at `{workspaces_dir}/{name}/tasks/`
2. `notes/` directory exists at `{workspaces_dir}/{name}/notes/`
3. `agent-artifacts/` directory exists at `{workspaces_dir}/{name}/agent-artifacts/`
4. Canonical note `{name}.md` exists (already confirmed above)
5. Canonical note contains a horizontal rule (`---` on its own line, separate from frontmatter delimiter) — the above/below-the-rule split
6. Below-the-rule sections present: `## Current State`, `## What's Next`, `## Open Questions`, `## Learnings`, `## Recent Sessions`

**Strict mode — additional checks:**

7. Frontmatter present and contains all required fields: `type: note`, `kind: workspace`, `title:`, `aliases:`, `description:`, `created:`, `modified:`
8. `type:` value is `note`
9. `kind:` value is `workspace`
10. `aliases:` includes the kebab-case workspace name
11. For each `.md` file under `tasks/`: frontmatter has `type: task` and `workspace: "[[{name}]]"`
12. For each `.md` file under `notes/`: frontmatter has `type: note` and a valid `kind:` (research, decision, plan, spec, learning, brainstorm, idea, user-story, or other content kind)
13. For each `.md` file under `agent-artifacts/`: frontmatter has `type: agent-artifact` and `artifact_kind:` set to one of `plan`, `spec`, `review`, `log`, `summary`

### Output format

Print a structured report:

```
Workspace audit: {name}
Mode: {strict | minimal}
─────────────────────────────────────
PASS  tasks/ exists
PASS  notes/ exists
FAIL  agent-artifacts/ missing
        → mkdir {workspaces_dir}/{name}/agent-artifacts/
PASS  canonical note exists
PASS  above/below-the-rule split present
FAIL  missing below-the-rule section: ## What's Next
        → add "## What's Next" section below the horizontal rule
...
─────────────────────────────────────
{n} checks passed, {m} failed.
```

For each FAIL, include a concrete remediation suggestion indented below it.

### Do NOT auto-fix

Report only. The user reviews the report and decides what to repair. Do not write, move, or modify any files during the audit.

## Confirmation Requirements

**ALWAYS confirm before creating a workspace.** The creation confirmation rule is non-negotiable — workspace creation is a significant structural action. Never create silently, even if the user's intent seems unambiguous.

No confirmation is required for the audit operation — reading and reporting is non-destructive.

## What NOT to Do

- Don't move existing files during create — only create new directories and the canonical note
- Don't auto-fix audit failures — suggest remediations, never repair automatically
- Don't write outside the workspace directory (`{workspaces_dir}/{name}/`)
- Don't push git commits or amend git history
- Don't create subdirectories beyond `tasks/`, `notes/`, `agent-artifacts/` (no `plans/`, `specs/`, `research/` subfolders — that violates the flat structure rule)
- Don't strip or rewrite frontmatter fields that may be managed by external indexers (especially `document_id`, `aliases`, `title`, `description`)
