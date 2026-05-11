# Mini-Vault Contract

Every workspace in a brain-kit vault follows this contract. It defines what a workspace is, what it contains, and how agents and humans interact with it.

## Why This Contract Exists

Workspaces serve as both documentation and the memory layer for AI agents. A standard structure means any agent can navigate any workspace without rediscovery — it knows where tasks live, where canonical notes live, and where generated artifacts go. The above/below-the-rule split gives agents a safe write zone while keeping human-authored context protected. Without this contract, agents accumulate redundant context files and overwrite human work.

## Directory Structure

Every workspace lives at:

```
{workspaces_dir}/{name}/
├── {name}.md          # Canonical workspace note — root of navigation
├── tasks/             # Durable task notes
├── notes/             # Canonical workspace content notes
└── agent-artifacts/   # Generated coding-agent execution artifacts
```

- `{name}` is **kebab-case**: lowercase letters, digits, and hyphens only. No spaces, no underscores, no uppercase.
- `{workspaces_dir}` defaults to `Workspaces` in the vault root (configurable via `vault.workspaces_dir` in `.vault.toml`).

## The Canonical Workspace Note

`{name}.md` is the root of all navigation for this workspace. Every other file in the workspace links back to it (directly or indirectly).

### Above/Below-the-Rule Split

Every canonical note contains a horizontal rule (`---` on its own line, distinct from the YAML frontmatter delimiter) that divides the note into two zones:

```
<!-- Above the rule: human-authored, durable across sessions -->

# {name}

One-paragraph preamble, tech stack, key paths, conventions, navigation links.

---

<!-- Below the rule: agent-maintained, may be overwritten by /devlog write -->

## Current State
## What's Next
## Open Questions
## Learnings
## Recent Sessions
```

**Above the rule** — human-authored content. This is the durable source of truth: what the workspace is, why it exists, tech stack, key paths, conventions, navigation. Agents MUST NOT overwrite content above the rule.

**Below the rule** — agent-maintained session state. Updated by `/devlog write` at session end. Humans may edit, but should expect overwrites. Required sections: `## Current State`, `## What's Next`, `## Open Questions`, `## Learnings`, `## Recent Sessions`.

## Subdirectory Purposes

### `tasks/`

Durable task notes for this workspace. Tasks are not transient to-dos — they are tracked, typed files with a lifecycle.

Each task file:
- Is a separate `.md` file
- Represents one actionable unit of work
- Has a status lifecycle: `backlog → in_progress → completed | wont_do`

### `notes/`

Canonical workspace content notes. This is where plans, specs, decisions, research, learnings, user-stories, and brainstorms live when they reach durable knowledge status. Human-authored or promoted from agent artifacts.

No subfolders inside `notes/` — flat structure only. No `plans/`, `specs/`, `research/` subfolders.

### `agent-artifacts/`

Generated coding-agent execution material: plans, specs, reviews, logs, and summaries produced by AI agents during implementation sessions. These are working reference documents, not canonical knowledge — unless their durable content is extracted and rewritten as a canonical `notes/` entry.

Agent artifacts are NOT canonical notes. They are not linked from the main workspace navigation unless explicitly promoted.

---

## Strict Mode

When `mode.strict = true` in `.vault.toml`, the following additional rules apply.

### Canonical Note Frontmatter

The canonical workspace note must have all of these frontmatter fields:

```yaml
---
type: note
kind: workspace
title: {human-readable workspace name}
aliases:
  - {kebab-case name}
description: {one-line description}
created: YYYY-MM-DDTHH:mm
modified: YYYY-MM-DDTHH:mm
---
```

Required field values:
- `type` must be `note`
- `kind` must be `workspace`
- `aliases` must include the kebab-case workspace name
- `created` and `modified` must be present (format: `YYYY-MM-DDTHH:mm`)

### Task Files (strict mode)

Every `.md` file under `tasks/` must have:

```yaml
---
type: task
workspace: "[[{name}]]"
status: backlog | in_progress | completed | wont_do
---
```

- `type` must be `task`
- `workspace` must be `"[[{name}]]"` where `{name}` is the workspace kebab-case name
- `status` must be one of the four lifecycle values

### Notes Files (strict mode)

Every `.md` file under `notes/` must have:

```yaml
---
type: note
kind: {content-kind}
---
```

- `type` must be `note`
- `kind` must be a valid content kind: `research`, `decision`, `plan`, `spec`, `learning`, `brainstorm`, `idea`, `user-story`, or other recognized content kind (not `workspace`, `domain`, `persona`, or structural kinds)

### Agent Artifact Files (strict mode)

Every `.md` file under `agent-artifacts/` must have:

```yaml
---
type: agent-artifact
artifact_kind: plan | spec | review | log | summary
---
```

- `type` must be `agent-artifact`
- `artifact_kind` must be one of: `plan`, `spec`, `review`, `log`, `summary`

---

## Minimal Mode

When `mode.strict` is absent or `false`, only the structural requirements apply:

- Directory structure: `{name}/`, `tasks/`, `notes/`, `agent-artifacts/`
- Canonical note `{name}.md` must exist
- Canonical note must contain the above/below-the-rule split
- Below-the-rule sections must be present (`## Current State`, `## What's Next`, `## Open Questions`, `## Learnings`, `## Recent Sessions`)

No frontmatter is required. Files inside `tasks/`, `notes/`, and `agent-artifacts/` have no enforced frontmatter requirements.

---

## Contract Compliance Summary

| Check | Minimal | Strict |
|---|---|---|
| `tasks/` dir exists | required | required |
| `notes/` dir exists | required | required |
| `agent-artifacts/` dir exists | required | required |
| `{name}.md` canonical note exists | required | required |
| Horizontal rule split present | required | required |
| Below-the-rule sections present | required | required |
| Canonical note frontmatter (`type`, `kind`, `title`, `aliases`, `description`, `created`, `modified`) | — | required |
| Task files: `type: task`, `workspace: "[[{name}]]"`, `status` | — | required |
| Note files: `type: note`, valid `kind` | — | required |
| Agent artifact files: `type: agent-artifact`, valid `artifact_kind` | — | required |
