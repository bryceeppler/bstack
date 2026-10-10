---
name: arena
description: "Spawn N parallel candidates at the same task, pick a base, graft the strongest parts of the losers into it. Use for /arena, 'arena this', 'throw it in the arena', or when one attempt at a non-trivial artifact would lock in the wrong shape."
disable-model-invocation: true
---

# Arena

A skill named in bold or in backticks, or run as `/<name>`, is the file `../<name>/SKILL.md` beside this skill's directory, and a principle named without its prefix is `../principle-<name>/SKILL.md`. Read the file and follow it. Most pstack skills are user-only, so your skill tool cannot load them. Every `delegate_task` call follows the defaults in the Subagents section of `../poteto-mode/SKILL.md`.

Fan out N parallel attempts at the same task. Read every candidate end to end. Pick the strongest as the base. Graft the best ideas from the others into it. Verify the synthesized result.

## Start

Open a task list (your harness's task tool, or a checklist file at `~/.local/state/pstack/checklists/<repo>-<branch>.md` when it has none) with one entry per phase before launching anything.

1. Frame
2. Fan out
3. Cross-judge
4. Pick
5. Graft
6. Verify

## Phase A: Frame

The N candidates will receive the same prompt, so the prompt is the contract.

1. State the artifact each candidate is producing.
2. Derive the rubric. State what success looks like for *this* task, then turn it into 3-6 concrete gradeable criteria. The rubric is the picker's tool in Phase D. Candidates only see the task.
3. Pick the runners. Use the `arena runners` line in `~/.config/pstack/pstack-models.md`, one seat per entry. If the file or that line is missing, default to one seat on the parent thread's model and one on the strongest model of each other provider that `orchestrator_capabilities` reports with `canRunChildTask`, up to three seats. Say so and suggest `/setup-pstack`. An entry `<providerInstanceId>/<model> (<effort>)` sets the seat's provider, model and the effort option id `orchestrator_capabilities` lists for that model. An `auto` or `inherit-parent` entry in this line or the cross-judge line means the parent model: omit the whole `target` for a `delegate_task` seat, and omit `modelSelection` for a `t3_thread_launch` candidate so it inherits. If T3 rejects a configured entry, run that seat on the closest model of the same provider that `orchestrator_capabilities` lists and say so. Spawn more when the arena covers multiple design directions. Same model N times when the work is generation-bound rather than judgment-sensitive.
4. Assign output paths. Each candidate writes to its own location (a git worktree where possible, otherwise `/tmp/arena-<slug>/candidate-<n>/`), per the **separate-before-serializing-shared-state** principle skill. A candidate that writes code gets its own worktree. Commit the base first, because uncommitted edits do not reach a new worktree.

## Phase B: Fan out

Spawn all N candidates in one turn, each with the task, the absolute path to the shared grounding, its own output path, and instructions to produce both the artifact and a short rationale. A candidate that writes code is a `t3_thread_launch` thread titled `arena <slug>: candidate <n>`, with `workspaceStrategy: {"type":"worktree","baseRef":"<base commit>","branch":"arena-<slug>-<n>","startFromOrigin":false}`, `modelSelection: {"instanceId": ..., "model": ..., "options": ...}` from its seat, and the brief in `message`. Wait on it with `t3_thread_wait` and take its worktree path from `t3_thread_read`. Any other candidate is a `delegate_task` child with `mode: "async"`, the same title, `target` from its seat, and its `/tmp` output path. Its completion notification wakes you.

Each rationale names the alternatives the candidate considered and what it rejected.

If a candidate fails to produce output, proceed with N-1 and note the dropout in the synthesis record.

## Phase C: Cross-judge

After all Phase B candidates complete, choose one model from the `arena cross-judge pool` line in `~/.config/pstack/pstack-models.md`. If the file or that line is missing, choose from the strongest model of each provider that `orchestrator_capabilities` reports with `canRunChildTask`. Prefer a different model family from the parent's (usually, not always, a different provider) when the pool allows. Spawn one judge on that model as a `delegate_task` child with `mode: "async"`, titled `arena <slug>: cross-judge`, its brief saying read-only: inspect only, no writes, no git commands. It sees the rubric and the candidates by absolute path label, scores each criterion, and recommends a base with rationale. It runs in parallel with the parent's reading in Phase D, not with the candidates themselves. Don't spawn the judge while candidates are still writing.

## Phase D: Pick a base

Read every candidate end to end before picking.

Score each candidate against the rubric criterion by criterion, not on holistic feel. Compare against the cross-judge. Agreement on the base confirms the pick. Disagreement means one of you is biased or the rubric was ambiguous. Read both rationales before deciding.

Pick the base on which candidate a future maintainer can extend most easily without breaking invariants. Prefer the cleaner boundary or smaller API when two feel tied, per the Laziness Protocol.

Record the pick and the reason in a short synthesis note alongside the base artifact, including the cross-judge's verdict.

## Phase E: Graft

Walk each losing candidate once more and identify what is worth porting into the base. The signal is usually one or two things per candidate, not most of it.

Fold each graft in by hand, per the **redesign-from-first-principles** principle skill. Don't paste mechanically. The result has to remain coherent under one mental model.

Record what was grafted, from which candidate, and what was rejected and why.

When N candidates converge on the same shape, that is a strong agreement signal. Note the convergence in the record and ship the consensus shape. No graft is needed. When N candidates wildly diverge, Phase A was under-specified. Reframe and re-run rather than averaging the divergence.

## Phase F: Verify

The synthesized artifact has to hold up under the same scrutiny as any other output, per the **prove-it-works** principle skill.

If verification surfaces a problem the arena did not catch, either Phase A was wrong (re-frame and re-run) or one candidate caught it and you missed the graft (go back to Phase E). Don't paper over.

## Outputs

One synthesized artifact. One short synthesis note alongside, naming the base, the grafts (with source candidate), the rejections, the dropouts if any, and the verification result.
