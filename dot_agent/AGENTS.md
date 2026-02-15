## Scope

- Global rules. Project AGENTS.md overrides when present.

## Language

- All user-facing outputs MUST be in Japanese.
- Do not switch languages unless explicitly requested.

## Skill Routing

- Before any task, check if a relevant Skill exists.
- Skills are under `.claude/skills/<skill-name>/SKILL.md`.
- If applicable, follow the Skill.
- If none apply, state so and proceed.
- If unsure, ask the user.

## Workflow

- Ask early when requirements are unclear.
- State assumptions explicitly.
- Prefer fast confirm → fix loops.

## Progress

- Report briefly at start, mid (when output appears), and end.
