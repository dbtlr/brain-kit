---
name: partner-model bootstrap
description: Subcommand of partner-model. Seeds the consolidated model from a persona file (if present) or a brief interview (5 questions). Idempotent — no-op if model already exists with content.
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion]
---

# partner-model bootstrap

## Overview

This subcommand seeds the partner model on first run. It checks for an existing persona file at the resolved `persona.path` and, if found and non-empty, derives initial log entries from it without prompting the user. If no persona file is present or it is empty, the subcommand runs a short five-question behavioral interview conversationally via `AskUserQuestion`. In either case, after writing seed entries to the JSONL log, it invokes the `consolidate` subcommand to produce the initial model markdown from those entries. The result is a fully initialized model file ready for passive observation in subsequent sessions.

## When to use

Invoke manually when the user runs `/partner-model bootstrap`, or invoke automatically by the `brain-init` skill (Task 10) during new vault setup. Either way, it is safe to call multiple times — the idempotency check ensures a second invocation is a no-op when the model already contains content.

## Step 1: Resolve config

Use the same three-tier path resolution defined in `SKILL.md` under **File Locations** — do not duplicate the logic here. The outcome is:

- **Model path** — absolute path to the consolidated model markdown file.
- **Log path** — absolute path to the JSONL log file.
- **Persona path** — resolved from `$PERSONA_PATH` (env var) if set, or from the `persona.path` key in `.vault.toml` relative to vault root (using the same vault-root calculation as tier 2 of the main skill). If neither source is set, persona path is unset.
- **Profile** — the `partner_model.profile` value from `.vault.toml`, or `"default"` if absent. Used in the summary output only; it does not affect log path.

If no writable path can be determined (tier 3 directory creation also fails), abort with an informative message and exit cleanly — do not write anything.

## Step 2: Idempotency check

Read the model file at the resolved model path. If the file exists AND contains more than just a YAML frontmatter block (i.e., there is non-whitespace content below the closing `---`), the model is already initialized. Print:

```
partner-model already initialized at {path}.
Use `consolidate` to refresh from logs.
```

Then exit cleanly. This is not an error — the user simply does not need bootstrap.

To test: check file existence first (`Bash` with `test -f "$MODEL_PATH"`), then if it exists, count meaningful lines with `grep -v '^---' "$MODEL_PATH" | grep -c '\S'`. If the count is greater than zero, treat it as initialized.

## Step 3: Choose seeding source

Determine which seeding path to take:

- If a persona path is resolved AND the file exists at that path AND it is non-empty (`test -s "$PERSONA_PATH"`) → proceed to **Step 4a: Seed from persona**.
- Otherwise → proceed to **Step 4b: Run interview**.

Record which branch was taken — you will need `"persona"` or `"interview"` for the summary in Step 7.

## Step 4a: Seed from persona

Read the persona file in full. Scan for signals in sections such as (but not limited to): "Current role", "What I'm optimizing for", "Stakeholders", "Growth edges", "Context", "Projects". For each meaningful behavioral signal, produce one JSONL log entry. Do not invent observations — only write entries the persona file directly supports with its own text.

**Mapping examples:**

| Persona content | Derived log entry text |
|---|---|
| `Current role: Senior Staff Engineer at TechCorp` | `[seed-from-persona] User is a senior staff engineer; assume technical depth and systems thinking by default.` |
| `What I'm optimizing for: Shipping data platform v3 by Q3` | `[seed-from-persona] User is currently focused on data platform v3 (Q3 deadline); prioritize work that advances this goal.` |
| `Stakeholders: VP Eng (weekly syncs), cross-functional leads` | `[seed-from-persona] User manages up to VP Eng and coordinates across functions; context around visibility and stakeholder communication matters.` |
| `Growth edges: Delegation, writing more concisely` | `[seed-from-persona] User is actively working on delegation and concise writing; avoid over-explaining when brevity is clearly sufficient.` |

All entries use:
- `type: observation`
- `session: bootstrap-seed-{timestamp}` where `{timestamp}` is the ISO 8601 UTC timestamp at the start of bootstrap (e.g., `bootstrap-seed-2026-05-10T14:00:00Z`)
- `pattern_ref: null`
- Text prefixed with `[seed-from-persona]`

Count the entries produced. Proceed to **Step 5**.

## Step 4b: Run interview

Ask the five questions from `references/seed-prompts.md` **one at a time**, conversationally. Do not present them as a numbered list or a form. Use `AskUserQuestion` for each. The interview should feel like a quick calibration conversation, not an intake form.

**Question guidance:**

1. **Receiving options** — Ask whether the user prefers a recommendation up front or all options laid out. Provide two or three labeled choices (e.g., "Recommendation first", "All options, then decide", "Depends on the stakes") so they can pick quickly, but accept free-text too.

2. **Decision speed** — Ask whether they tend to discuss/iterate before deciding or pick fast and refine through doing. Same format: two or three options plus room for nuance.

3. **Failure response** — Ask whether, when something fails, they want an immediate fix attempt or root-cause analysis first. Short choices work well here.

4. **Communication style** — Ask whether terse acknowledgments ("ok", "yes") are fine or whether they want explicit confirmation the agent understood. Two options plus "Other" path for nuance.

5. **Past friction (optional, open-ended)** — Ask what agent behaviors in past sessions have grated on them, or what they want to avoid. Frame it as optional. Accept free-text only — do not constrain this one with choices. If they decline or say "nothing", skip writing an entry for this question.

For each non-skipped answer, derive one or two JSONL log entries. Use:
- `type: observation`
- `session: bootstrap-seed-{timestamp}` (same timestamp used throughout this bootstrap run)
- `pattern_ref: null`
- Text prefixed with `[seed-from-interview]`

**Example entries:**

```jsonl
{"ts": "2026-05-10T14:00:00Z", "session": "bootstrap-seed-2026-05-10T14:00:00Z", "project": "brain-kit", "type": "observation", "pattern_ref": null, "text": "[seed-from-interview] User prefers recommendation-first option presentation. Confirmed during bootstrap interview."}
{"ts": "2026-05-10T14:00:00Z", "session": "bootstrap-seed-2026-05-10T14:00:00Z", "project": "brain-kit", "type": "observation", "pattern_ref": null, "text": "[seed-from-interview] User picks fast and refines through doing; avoid extended deliberation loops before acting."}
```

Count the entries produced. Proceed to **Step 5**.

## Step 5: Append seeds to log

Ensure the log file's parent directory exists. For tier-3 (default fallback), create it if needed:

```bash
mkdir -p "$(dirname "$LOG_PATH")"
```

For tier-2 (vault-resolved), do NOT create directories — the vault structure is owned by the user. If the directory does not exist under tier 2, the skill should have already fallen back to tier 3 in Step 1.

Append each seed entry to the log file, one JSON object per line, using the `echo >>` pattern from `SKILL.md`:

```bash
echo '{"ts": "...", "session": "...", "project": "...", "type": "observation", "pattern_ref": null, "text": "..."}' >> "$LOG_PATH"
```

The `project` field for all seed entries is the current project. Use `basename "$PWD"` if no better project context is available.

Never overwrite or truncate the log. Append only.

## Step 6: Run consolidation

Invoke the `consolidate` subcommand (`consolidate.md` — Task 7, forward dependency). Consolidation reads the JSONL log and rewrites the model markdown with sectioned patterns derived from all entries, including the seeds just written.

After consolidation completes, the model file at the resolved model path should exist with structured pattern sections. If consolidation is not yet implemented (Task 7 pending), write a minimal stub model file to unblock usage:

```markdown
---
generated: {timestamp}
profile: {profile}
seed_source: {persona|interview}
---

# Partner Model

> Bootstrapped from {seed_source}. Run `consolidate` to produce full model.
```

This stub satisfies the idempotency check on future invocations.

## Step 7: Print summary

This is the one point where the partner-model skill communicates directly with the user — bootstrap is an explicit setup command, so user-facing output is appropriate here (unlike passive observation during sessions).

Print:

```
✓ partner-model bootstrapped
  Model: {model_path}
  Log: {log_path}
  Seed source: {persona|interview}
  Entries seeded: {count}
  Profile: {profile}

Initial model written. Future sessions will refine via observation + periodic consolidation.
```

Where:
- `{model_path}` — resolved absolute path to the model file
- `{log_path}` — resolved absolute path to the JSONL log file
- `{persona|interview}` — whichever branch was taken in Step 3
- `{count}` — number of seed entries written in Step 5
- `{profile}` — resolved profile name (e.g., `default`, `work`, `personal`)
