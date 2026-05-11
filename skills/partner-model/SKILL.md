---
name: partner-model
description: Maintains a persistent model of the user's working style, preferences, and collaboration patterns. Loads on session start; observes during the session; appends focused log entries at session end.
allowed-tools: [Read, Write, Edit, Bash]
---

# Partner Model

## Overview

You maintain a living model of the user you work with — their technical style, communication patterns, decision-making tendencies, and collaboration preferences. The user has opted in by installing this skill but is not an active participant in its maintenance. Do not announce reads, writes, or updates.

## File Locations

Resolve paths in this order:

**1. Environment variable (highest priority):**
If `$PARTNER_MODEL_PATH` is set, use it as-is for the consolidated model. Derive:
- **Log file:** `${PARTNER_MODEL_DIR}/logs/partner_model_log.jsonl`
- **Config:** `${PARTNER_MODEL_DIR}/logs/partner_model_config.json`

where `PARTNER_MODEL_DIR` is the parent directory of `$PARTNER_MODEL_PATH`.

**2. Vault config discovery:**
If `$PARTNER_MODEL_PATH` is not set, invoke `${CLAUDE_PLUGIN_ROOT}/scripts/detect-vault-config.sh` (with `$PWD` as the start directory). If it succeeds and prints a `.vault.toml` path:
- Parse `.vault.toml` using `grep`/`awk` (be robust to comments and whitespace).
- Read `partner_model.path` (default: `System/partner_model.md`) and `partner_model.log_path` (default: `System/logs/partner_model_log.jsonl`).
- Resolve both paths relative to the **vault root**. The vault root is computed as: if `vault.root` is absolute (starts with `/`), use it as-is; otherwise resolve `vault.root` relative to the directory containing `.vault.toml`. The convention `vault.root = "."` (the default) means the directory containing `.vault.toml` is the vault root.
- If `partner_model.profile` is set and not `"default"` (default is `"default"` if unset), append the profile to the model filename: `partner_model.md` → `partner_model.${profile}.md`. The log path is NOT split by profile (logs are shared across profiles in v0.1).
- **Do not create directories** under tier 2 — the vault structure is owned by the user. If the resolved log path's parent directory does not exist, fall back to **tier 3** (default).

**3. Default fallback:**
If neither of the above succeeds, use:
- **Consolidated model:** `~/.claude/partner-model/default.md`
- **Log file:** `~/.claude/partner-model/logs/log.jsonl`

Create the directory structure if it doesn't exist.

**If no writable path can be determined, do nothing.** This skill is inactive without a configured location.

## Auto-load via SessionStart hook

The plugin's `SessionStart` hook (`hooks/session-start.sh`) reads the model file at session start and outputs it as initial context, wrapped in `<partner-model>` tags. **You do not need to load the file manually** — it is already in your session context if a vault config or `$PARTNER_MODEL_PATH` was reachable.

If you are running in a context where the hook did not fire (manual invocation outside a brain-kit-aware session, or `$PARTNER_MODEL_PATH` was set after the hook ran), read the consolidated model file yourself using the resolved path above.

## Persona Awareness

After loading the consolidated model, check for a persona file:
- If `$PERSONA_PATH` is set, read it.
- Else, if `.vault.toml` has a `persona.path` key, resolve it relative to vault root (using the same vault root calculation as in File Locations tier 2) and read it.

If a persona file exists, treat it as **declared facts about the user** — role, focus areas, stakeholders, organizational context. These complement the **observed patterns** in the partner model. The persona informs interpretation: if the persona says "user is a senior staff engineer," assume technical depth even before you've observed it directly.

Do NOT update the persona file. It is hand-maintained by the user.

## Profile Semantics

Profiles let one user maintain separate partner models per context (e.g., `work`, `personal`, `oss`). Profile is set via `partner_model.profile` in `.vault.toml`. A different profile means a different model file and an independent observation lineage — sessions under one profile do not pollute another.

In v0.1, logs are NOT split by profile. All profiles share `partner_model_log.jsonl`. Profile-scoped logs are deferred to v0.2.

## Observing During Sessions

Throughout the session, notice patterns but **do not write to the log mid-session**. Batch observations for session end. The goal is to avoid interrupting flow.

Look through these lenses (not as a template — as things to notice):
- **Technical depth and domains** — What can you assume they know? Where do they go deep vs. defer?
- **Communication style** — How do they signal agreement, uncertainty, frustration, delegation?
- **Decision-making patterns** — Do they decide fast or deliberate? Want options or recommendations?
- **Process preferences** — Planning vs. doing? Testing? Documentation? Version control?
- **Collaboration dynamics** — When do they want autonomy vs. discussion?

## Session-End: Writing Log Entries

At session end, append entries to the JSONL log file. Each entry is one line, one focused observation.

### The Filter

Before writing any entry, ask: **"Would a fresh agent, starting a new session tomorrow with no context about today, work differently if it knew this?"**

If no, skip it. If yes, write it.

### Entry Schema

```jsonl
{"ts": "2026-04-11T22:00:00Z", "session": "norn-cleanup-pr1", "project": "norn", "type": "observation", "pattern_ref": null, "text": "One focused observation that passes the filter."}
```

Fields:
- **ts** — ISO 8601 timestamp
- **session** — human-readable session identifier (project + what happened)
- **project** — which project this was observed in
- **type** — one of: `observation`, `confirmation`, `correction`, `calibration`
- **pattern_ref** — short descriptive string referencing an existing pattern being confirmed or corrected. Null for new observations.
- **text** — the observation. One sentence to short paragraph. Must pass the filter.

### Entry Types

- **observation** — genuinely new pattern. Nothing in the current model covers this.
- **confirmation** — existing pattern held in a meaningfully different context. Not worth logging if the context is routine — only log when the new context adds signal.
- **correction** — the model is wrong or incomplete. **Highest-value type.** This is how the model self-corrects. "Model says X, but this session showed Y because Z."
- **calibration** — something that caused friction this session that the model could have prevented. Bug reports against the model.

### Writing Rules

1. **Do not read the log before writing.** Observations should be pure and unbiased. Deduplication is consolidation's job.
2. **Project field is required.** Always include which project the observation came from.
3. **Challenge prior precedent.** If the model says X but this session showed Y, that's a correction — log it explicitly with a `pattern_ref` pointing to the existing pattern.
4. **No max entries.** Trust the filter to keep it reasonable.
5. **Append only.** Add new lines to the end of the file. Never modify existing entries.

### How to Append

**One JSON object per line.** Every entry must be its own line with the full schema (ts, session, project, type, pattern_ref, text). Do NOT bundle multiple observations into an array or omit fields — the consolidator reads line-by-line and needs the type classification per entry.

```bash
echo '{"ts": "...", "session": "...", "project": "...", "type": "...", "pattern_ref": null, "text": "..."}' >> "$LOG_FILE_PATH"
```

## Subcommands

- **bootstrap** — first-run setup: derives initial observations from a persona file (and optionally from past Claude Code conversation logs). Never asks the user about preferences. See `bootstrap.md` and `references/seed-sources.md`.
- **consolidate** — reads the JSONL log and rewrites the consolidated model markdown. Use the `consolidate` subcommand (see `consolidate.md`).

## What NOT to Do

- **Do not edit the consolidated model directly.** It's generated by consolidation.
- **Do not announce** reads, writes, or updates to the user.
- **Do not ask the user** about the model's contents or structure.
- **Do not write entries mid-session.** Batch for session end.
- **Do not run git commands against the vault.** The vault owns its own git lifecycle. Write the log entry and stop; the vault's automation (if any) handles commits.
- **Do not log routine confirmations.** "User gave terse answers during brainstorming" for the 10th time is noise.

## Silent Operation

**CRITICAL**: Never announce reads, writes, or updates to this file. The user knows this system exists — maintain it silently and let it inform your behavior naturally.
