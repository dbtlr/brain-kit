# Seed Sources for partner-model bootstrap

The `bootstrap` subcommand seeds the consolidated model with **inferred observations** derived from existing evidence about the user. It does **not** ask the user about their preferences — that would invert the model's premise. Observations are what the agent has seen, not what the user has declared.

This skill identifies sources of behavioral evidence, derives observations from them, and writes those observations to the log as `[seed-from-*]` entries. Consolidation then turns them into the initial model.

## Primary source: persona file

If a persona file exists at the resolved `persona.path`, derive observations from its declared facts. Each fact maps to one or more observations the agent can reasonably infer.

### Mapping examples

| Persona declaration | Derived observation (logged) |
|---|---|
| `Current role: Senior Staff Engineer at TechCorp` | `[seed-from-persona] User is a senior staff engineer; assume technical depth and systems thinking.` |
| `What I'm optimizing for: Shipping data platform v3 by Q3` | `[seed-from-persona] User is currently focused on data platform v3 (Q3 deadline); prioritize work that advances this.` |
| `Stakeholders: VP Eng (weekly syncs), cross-functional leads` | `[seed-from-persona] User manages up to VP Eng and coordinates across functions; visibility and stakeholder context matter.` |
| `Growth edges: Delegation, writing concisely` | `[seed-from-persona] User is working on delegation and concise writing; avoid over-explanation when brevity suffices.` |

**Rules:**

- Encode only what the persona directly supports. Do not invent or extrapolate.
- One observation per declared fact, unless a fact naturally implies multiple distinct behavioral patterns.
- Persona is treated as declared truth, not as observed behavior. The model will refine these through real observation later.

## Optional source: Claude Code conversation logs

If `~/.claude/projects/` exists and contains conversation logs from prior sessions, scan recent conversations for additional observational signal. This is opt-in via `mode.crawl_cc_logs = true` in `.vault.toml` (or a `--with-cc-logs` flag at bootstrap time). Default is **off** — this reads user content and should be explicit.

### Discovery

Conversation logs live at `~/.claude/projects/<dash-encoded-path>/` with JSONL conversation files inside. Each project directory corresponds to one working directory (`/` replaced with `-`). Bound the crawl by recency (e.g., files mtime within the last 30 days) and total count (e.g., last 50 conversations across all projects).

### What to look for

- **Communication style** — average user-message length, terseness vs. expansiveness, error-output pasting habits, typo patterns.
- **Decision patterns** — how the user responds to options (picks fast / weighs all / asks for recommendation).
- **Correction signals** — places where the user pushed back ("no", "stop", "don't") or rewrote what the agent did. High-value: reveals what grates.
- **Tool / domain preferences** — which tools, languages, frameworks, file types recur.
- **Workflow patterns** — planning before coding? Iterating live? Testing before/after? Discussing before deciding?

### What NOT to do

- **No verbatim content from conversations.** Derive abstract patterns only. The log entry text should describe behavior, not quote messages. ("User defaults to terse acknowledgments" — yes. "User wrote 'just do it' on 2026-04-15" — no.)
- **No sensitive-content surfacing.** If a conversation touches PII, credentials, or private topics, skip it entirely — don't try to filter mid-stream.
- **No cross-project leakage.** Patterns observed in one project may not apply to others. Tag observations with the project they came from in the `project` field of the log entry.
- **No overfitting to small samples.** A single instance is anecdote, not pattern. Require ≥2 distinct sessions showing the same signal before encoding.

### Mapping examples

| Observed pattern (across recent CC logs) | Derived observation |
|---|---|
| User pastes raw error output without commentary 8+ times | `[seed-from-cc-logs] User shares errors as-is — parse them; don't ask what's wrong.` |
| User says "wait" / "stop" / "don't" 5+ times in past month | `[seed-from-cc-logs] User interrupts to course-correct early; treat soft signals as hard stops.` |
| User's average message length < 50 chars over many sessions | `[seed-from-cc-logs] User communicates tersely; match that brevity in responses.` |
| Decisions usually preceded by 1–2 turns of discussion, not lengthy spec | `[seed-from-cc-logs] User decides fast; over-deliberation grates.` |

## When neither source exists

If no persona file is configured **and** CC log crawling is disabled (or yields no usable signal), bootstrap writes an empty model file with just frontmatter, then exits cleanly. The model populates via real session observation and periodic consolidation.

An empty model is more honest than a fabricated one. The partner-model is observation-first by design; absence of observations means the model has nothing to say yet, which is fine.

## Implementation status

- **v0.1:** persona-file seeding implemented; CC log crawling specified but **not yet implemented** (deferred to v0.2). The opt-in config flag `mode.crawl_cc_logs` is recognized but currently does nothing. Tracked in `v0.2-and-beyond.md`.
