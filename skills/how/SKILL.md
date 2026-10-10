---
name: how
description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Use why for motivation."
disable-model-invocation: true
---

# How

A skill named in bold or in backticks, or run as `/<name>`, is the file `../<name>/SKILL.md` beside this skill's directory, and a principle named without its prefix is `../principle-<name>/SKILL.md`. Read the file and follow it. Most pstack skills are user-only, so your skill tool cannot load them. Every `delegate_task` call follows the defaults in the Subagents section of `../poteto-mode/SKILL.md`.

Explore the codebase to answer "how does X work?" questions. Produce architectural explanations at the level of a senior engineer onboarding onto a subsystem, enough to build a working mental model, not so much that it reads like annotated source code.

Each spawn below is a `delegate_task` child with `mode: "async"`, and names a role line in `~/.config/pstack/pstack-models.md`. An entry `<providerInstanceId>/<model> (<effort>)` becomes `target: {"providerInstanceId": ..., "model": ..., "options": {"<effort option id>": "<effort>"}}`, with the effort option id `orchestrator_capabilities` lists for that model. Omit `target` when the value is `auto` or `inherit-parent`, or when the file or the line is missing, so the child runs on the parent thread's model. With no file, say so and suggest `/setup-pstack`. If `delegate_task` rejects an entry, use the closest model of the same provider that `orchestrator_capabilities` lists, and say so. The child gets only its brief, so the brief carries the filled prompt template and says read-only: inspect only, no writes, no git commands. End the turn after spawning and let the completion notifications wake you.

## Step 1. Assess Complexity

If the scope is ambiguous, state your interpretation and explore. The user can redirect.

- **Simple** (a single module, a small utility, a narrow question such as "how does function X work"): no explorers. One explainer explores and explains in a single pass. Go to Step 2b.
- **Complex** (a subsystem spanning multiple files or services, a cross-cutting feature, a full architectural overview): spawn parallel explorers first, then hand off to the explainer. Go to Step 2a.

When in doubt, take the simple path.

## Step 2a. Explore (complex questions only)

Decompose the question into 2 to 4 exploration angles, each a distinct slice of the subsystem. Spawn all explorers in a single turn:

- `title`: `how explorer: <angle>`
- `target`: the `how explorer` line

Each explorer gets the prompt in `references/explorer-prompt.md` with its angle filled in. Then go to Step 3.

## Step 2b. Direct Explain (simple questions)

Spawn one `delegate_task` child that explores and explains in one pass:

- `title`: `how explainer: <question>`
- `target`: the `how explainer` line

Build its prompt from `references/explainer-prompt.md` without the explorer-findings section. Go to Step 4.

## Step 3. Synthesize (complex questions only)

Once all explorers have returned, spawn one `delegate_task` child to synthesize their findings into one explanation:

- `title`: `how explainer: <question>`
- `target`: the `how explainer` line

Build its prompt from `references/explainer-prompt.md` with every explorer's findings filled in.

## Step 4. Present

Present the explainer's output to the user. Light edits for clarity or context from the conversation are fine. Do not substantially rewrite it.

## Output Format

The explanation uses the sections defined in `references/explainer-prompt.md`, dropping any that do not apply: Overview, Key Concepts, How It Works, Where Things Live, Gotchas.
