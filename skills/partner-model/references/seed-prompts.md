# Seed Prompts for partner-model bootstrap

The `bootstrap` subcommand uses these questions when no persona file exists. They focus on **behavioral** dimensions only — what the persona file would not capture. Five questions, conversational, brief.

## The Questions

1. **Receiving options:** Do you prefer a recommendation up front, or all options laid out for you to weigh?

2. **Decision speed:** Do you tend to discuss/iterate before deciding, or pick fast and refine through doing?

3. **Failure response:** When something fails, do you want a fix attempt immediately, or root-cause analysis first?

4. **Communication style:** Are terse acknowledgments fine ("ok", "yes"), or do you want explicit confirmation that the agent understood?

5. **Past friction (optional, open-ended):** Anything an agent has done in past sessions that grated on you? What kind of behavior do you want to avoid?

## Mapping Answers to Seed Entries

Each answer maps to one or more JSONL log entries with `type: observation` and `seed: true` in the entry text. Mark the session as `bootstrap-seed`.

Example:
```jsonl
{"ts": "2026-05-11T00:00:00Z", "session": "bootstrap-seed", "project": "brain-kit", "type": "observation", "pattern_ref": null, "text": "[seed-from-interview] User prefers recommendation-first option presentation. Confirmed during bootstrap interview."}
```

The `[seed-from-interview]` prefix (or `[seed-from-persona]` when bootstrap reads from a persona file) lets consolidation downgrade or remove these once observed entries cover the same ground.

## When to skip the interview

If a persona file exists at `persona.path`, derive seed entries from it instead of asking the user. The bootstrap subcommand handles that branch.
