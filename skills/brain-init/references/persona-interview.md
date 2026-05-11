# Persona Interview

Used by `brain-init` Step 9 when the user chooses **Build new via interview**. The interview builds the **persona file** (`me.md`) — declared facts about the user. It does **not** seed the partner model directly; the partner-model bootstrap derives observations from the persona afterward.

This is the right place to ask the user about themselves. The partner model is observation-only — see `skills/partner-model/references/seed-sources.md` for why those layers are kept separate.

## Tone

Conversational. One question at a time via `AskUserQuestion`. Open-ended. The user is describing themselves, not picking from a menu — provide a free-text path (`Other` in AskUserQuestion options, or just no options at all) so they can answer naturally.

This is a setup ritual, not a survey. ~5 questions, ~2-3 minutes total.

## The Questions

### 1. Professional context

> What do you do? Role, company (if relevant), the scope of your work.

Maps to persona section: `## Current role`

Example answers we'd expect:
- "Senior staff engineer at TechCorp, leading the data platform team."
- "Independent consultant — I help startups stand up their first observability stack."
- "Director of design at a 200-person SaaS, managing across two product lines."

### 2. Current focus

> What are you optimizing for right now? Goals, projects, timelines — anything that shapes how you're spending time over the next quarter or two.

Maps to persona section: `## What I'm optimizing for`

Example answers:
- "Shipping data platform v3 by Q3. Hiring two senior ICs in parallel."
- "Three client engagements wrapping up, then sabbatical."
- "Migrating our auth stack to passkeys, getting team headcount approved for next year."

### 3. Stakeholders & relationships

> Who do you work with most closely? Skip-levels, peers, cross-functional partners — anyone whose context matters when you're working.

Maps to persona section: `## Stakeholders`

Example answers:
- "VP Eng (weekly 1:1), three direct reports, two PMs, cross-functional with the data science group."
- "Co-founder Alex (I handle eng, they handle GTM). Distributed contractor team."
- "Engineering org-wide as IC; closest collaboration with platform and infra teams."

### 4. Growth edges

> What are you actively trying to get better at? Skills, habits, behaviors.

Maps to persona section: `## Growth edges`

Example answers:
- "Delegation — I still review too much code line-by-line. Writing more concisely."
- "Saying no to scope creep. Learning to coach rather than do."
- "Sleeping more. Public speaking."

### 5. Outside work (optional)

> What matters to you outside of work? Interests, values, anything that might be useful context when an agent makes recommendations.

Maps to persona section: `## Outside work`

This question is optional. If the user says "skip" or gives a short non-answer, leave the section empty (just the header). Some people prefer to keep work and personal context separate.

Example answers:
- "Family time on weekends. Long-distance running. Reading nonfiction."
- "Photography, especially street photography. Cooking."
- "(skipping)"

## Optional 6th question (catch-all)

> Anything else an agent should know about you that didn't come up?

Maps to: append to `## Outside work` or create a `## Notes` section in the persona if substantial.

Use this sparingly. If the user says "no" or gives a perfunctory answer, don't add a section.

## Assembling the persona file

After the interview, write the persona file at the resolved `persona.path` (default `${vault_root}/Notes/me.md`).

**Strict mode** uses the typed-note frontmatter from `_persona.md`:

```markdown
---
type: note
kind: persona
title: {user's name from question 1, or their handle if no name given}
aliases: []
description:
created: {current ISO 8601 timestamp}
modified: {current ISO 8601 timestamp}
---

## Current role

{answer to question 1}

## What I'm optimizing for

{answer to question 2}

## Stakeholders

{answer to question 3}

## Growth edges

{answer to question 4}

## Outside work

{answer to question 5 — or omit body if skipped}
```

**Minimal mode** skips the frontmatter (use `templates/minimal/persona.md`):

```markdown
# Persona

## Current role

{answer to question 1}

## What I'm optimizing for

{answer to question 2}

## Stakeholders

{answer to question 3}

## Growth edges

{answer to question 4}

## Outside work

{answer to question 5 — or omit body if skipped}
```

## After the interview

Once the persona file is written, brain-init's Step 9 invokes `/partner-model bootstrap`. The bootstrap detects the persona, derives observations from each declared fact, and writes them to the partner-model log as `[seed-from-persona]` entries. See `skills/partner-model/references/seed-sources.md`.

## Re-running the interview

The persona file is **hand-maintained** going forward. If the user's role, focus, or stakeholders change, they edit `me.md` directly. brain-init does not re-run the interview — it's a greenfield-only orchestrator.

If a user wants to rebuild their persona from scratch later, they can manually delete `me.md` and re-run `brain-init` (which will detect the missing config and decline; in that case, they'd just edit by hand). v0.2 may add a standalone `/persona rebuild` skill if this turns out to be a common request.
