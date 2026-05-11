# Log Entry Schema

Dev log entries are written by `/devlog write` to `{logs_dir}/`. Schema varies by vault mode.

---

## Filename Convention

```
{YYYY-MM-DD}_{HHMM}_{description-kebab-case}.md
```

With issue hint (extracted from branch name, e.g. `feat/PROJ-123` → `PROJ-123`):
```
{YYYY-MM-DD}_{HHMM}_{ISSUE-ID}_{description-kebab-case}.md
```

Description: 3–5 words, lowercase, hyphens. Example filenames:
- `2026-05-10_1430_add-user-auth.md`
- `2026-05-10_0915_PROJ-42_fix-prisma-pool.md`

---

## Minimal Mode

No required frontmatter. Just a title and sections.

```markdown
# {ISO timestamp} ({timezone}) - {Brief Title}

**Date:** YYYY-MM-DD
**Workspace:** {slug}
**Repo:** {repo-name}

## Overview

2–3 sentences. What was accomplished?

## Context

Why this work? Branch, issue IDs, user request. Link to prior session.

## Problem Analysis OR Implementation Approach

Bug fix → root cause discovery, investigation steps.
Feature → architecture, approach chosen.

## Implementation OR Solution

Specific changes: file paths, key patterns, algorithms, build issues resolved.

## Testing

How was the work validated? What was tested, what passed, what didn't?

## Design Decisions

**Why X not Y** — use Considered/Rejected/Chosen format for significant decisions.

## Key Learnings

Mistakes made and corrected. Surprises. Better approaches for next time.

## Files Modified

Grouped by repo if multi-repo work.

## Commits

Commit hashes and messages, or note if uncommitted with rationale.
```

---

## Strict Mode

Frontmatter required. Uses `type: log` (not `type: note, kind: log`).

```yaml
---
type: log
workspace: "[[{slug}]]"
date: YYYY-MM-DD
---
```

Body sections are identical to minimal mode:

```markdown
# {ISO timestamp} ({timezone}) - {Brief Title}

## Overview
## Context
## Problem Analysis OR Implementation Approach
## Implementation OR Solution
## Testing
## Design Decisions
## Key Learnings
## Files Modified
## Commits
```

### Design Note: `type: log` vs `type: note, kind: log`

Strict mode logs use `type: log` (a top-level type). This is intentionally inconsistent with `templates/strict/log.md`, which uses `type: note, kind: log` (the typed-note ontology). The discrepancy is inherited from the original dev-log behavior and preserved here for compatibility.

**Decision for v0.1:** Default to `type: log` for written log files. The template at `templates/strict/log.md` is for user-created notes that happen to be logs; dev-log skill entries are agent-generated session records with a different type hierarchy.

**Open question for v0.2:** Unify under `type: note, kind: log` across both the template and the skill, or formalize `type: log` as a distinct first-class type in the schema. Either path requires a migration decision.

---

## Conditional Sections

Add when relevant — not every log needs all of these:

| Section | When to include |
|---|---|
| `## Remaining Work` | Unfinished tasks, explicit follow-ups planned |
| `## Open Questions` | Unresolved questions blocking future work |
| `## Mysteries and Uncertainties` | Unexplained behaviors, gaps in understanding |
| `## References` | Related sessions, external docs, issue links |

---

## Quality Bar

- **Write for a future agent with zero memory of today.** Assume the reader knows nothing about this session.
- **More detail is always better than less.** 500-line entries are normal and valuable.
- **Document mistakes.** Failed approaches prevent future sessions from repeating them.
- **Design Decisions section is gold.** "Why X not Y" ages better than implementation specifics.
