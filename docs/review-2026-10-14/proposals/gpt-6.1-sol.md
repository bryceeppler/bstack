## Verdict

Keep the independent proof, head-bound approvals and shared project policy.
They caught real defects and protect decisions Bryce should retain.
The main drag is that agents still act as a transport and bookkeeping layer around T3.
Repeated wake, relay and cleanup patches make that boundary harder to trust.
The new lessons skill improves learning; another framework would mostly replace strengths.
First, run one builder round as a T3 child in its own worktree, with completion as its report.
Keep the merge gate and watcher during that pilot, then delete only the protocol the pilot makes unnecessary.
Success means fewer agent-managed steps with the same independent proof.

## Proposals

Ranked by expected value, with implementation sizes estimated rather than measured.
This review used all five reports, checked the source behind the recommendations below, and read the run results and named store records without traversing checker output.
I ran no framework scripts or live orchestration probes.
The shared checkout advanced during the review from the reports' `d46eabd` baseline to `80eae9d8be722545f32afee87e9ec4b8f8b65661`.
I read the intervening changes and fixed the review to `80eae9d`; repository citations below refer to that commit unless stated otherwise.
The new lessons skill, project-scoped transcript pack, automatic settling, away checks, skill-change detection and Claude shared-state hook are already implemented, so they are credited rather than proposed again.

Source abbreviations: `AC` is `/home/bryce/git/agent-configs`; `HZ` and `SC` are `/home/bryce/.claude/orchestrate/hzbook` and `/home/bryce/.claude/orchestrate/snapcaster`.
`T3` is `/tmp/agent-research/pingdotgg_t3code/repo`; `P` is `/tmp/agent-research/cursor_plugins/repo/pstack`; `FM` is `/tmp/agent-research/kunchenguid_firstmate/repo`.
`PM`, `CH`, `M` and `TF` are respectively the `pmwoz_t3-pstack`, `chhoumann_t3-pstack`, `mariusflorescu_pstack-t3` and `Tr1Fecta-7_p3-stack` clones under `/tmp/agent-research/`, each followed by `/repo`.

### 1. Let T3 own builder lifetimes and completion delivery

Problem: the builder-to-coordinator protocol has repeatedly lost the moment work became ready.
Run 10 needed an hourly nudge; the October 14 CI/mail runs left builders idle for 81 to 96 minutes after green CI; the latest pass still found a 27-minute stall despite the written fix (`AC/docs/plans/hzbook-run-results.md:142`, `:285-288`, `:350-352`).
The current builder brief spends its final five lines explaining reports, messages, waits and backup nudges (`AC/orchestrate/coordinator/templates/builder-brief.md:63-67`).

Change: make a builder round a bounded `delegate_task` with `isolation:"worktree"`, ending only after its proof, local gate, applicable PR checks and environment shutdown finish.
Let its terminal result carry the report path, PR and full head SHA to the coordinator.
Wait for the exact CI run in the foreground inside the child, with bounded waits and explicit failure results; remove the instruction to end a builder turn with a background CI command still running.
Keep fresh children for substantive fix rounds and independent review rounds.
Preserve the successful reuse of a builder for a description fix or rebase through `t3_thread_send`, recording the new task ID it returns.

Source and T3 mapping: T3 explicitly creates isolated child worktrees from the parent's local commit and delivers async completion (`T3/apps/server/src/mcp/OrchestratorMcpService.ts:2021-2057`).
The send tool explicitly supports a completed child's follow-up as a fresh task whose completion notifies its parent (`T3/apps/server/src/mcp/toolkits/orchestrator/tools.ts:236-238`).
The prohibition on reusing a child applies to independent review rounds, not builder conversation reuse (`T3/packages/provider-core/src/server/orchestrationInstructions.ts:9-11`).
Children also have no individual phone push (`T3/packages/shared/src/agentAwareness.ts:58-63`).

Prior decision: this revisits the October 13 rejection of builder delegation in the takeover plan's Port review and Snapcaster decision 3 (`AC/docs/plans/hzbook-pstack-takeover.md:187`, `AC/docs/plans/snapcaster-agent-workflow.md:24-27`).
The new facts are native worktree isolation and supported builder follow-ups, so neither the old missing-worktree reason nor the report's claim that reuse requires a top-level thread still holds.
Bryce has already requested this direction for Snapcaster's next lessons pass (`SC/rulings.md:62-63`).
For HzBook it remains a proposed change to the builder model, not assumed permission.

Deletes and adds: remove roughly 100 to 180 lines across builder launch/report/CI-nudge instructions and duplicated handling, while adding roughly 60 to 120 lines of child-task receipts and one shared launch template.
Do not delete `watch-run.sh` yet: external merges, base movement and Bryce's own GitHub comments still need coverage.

Risk and proof: an isolated child initially starts from local HEAD, so its first operation must fetch and reset its own branch to the intended remote base, or continue the recorded PR branch for a fix.
Pilot one small ticket through initial build, description follow-up, coordinator idle release and checker completion, then a second ticket through a substantive fix round.
Require one recorded builder per round, a report without a manual nudge, intact independent verification, and no leftover server; also prove Bryce can inspect and steer the app-owned child in the installed T3 build before removing the top-level alternative.

### 2. Make proof identity and coverage part of the refusing store

Problem: the ledger looks stronger than its input boundary.
`state.mjs verdict` accepts a lane and verdict string, then assigns the current round's SHA itself; it receives no checker task, judged SHA or result artifact (`AC/orchestrate/coordinator/bin/state.mjs:351-360`).
A delayed result from an earlier round could therefore be recorded against a newer verifying round.
Likewise, `round` accepts a subset of lanes without checking the claimed unchanged product code, while `standingVerdicts` carries earlier results (`AC/orchestrate/coordinator/bin/state.mjs:304-315`, `AC/orchestrate/coordinator/bin/lib.mjs:156-173`).
These are source-confirmed refusal gaps, not incidents I reproduced during this read-only review.

Change: accept a small structured checker result containing run, unit, round, attempt, task ID, full judged head, frozen base, verdict, acceptance-item evidence and artifact paths.
Have the store match it to the recorded launch before appending the ledger entry.
Give a replacement attempt its own output directory so a cancelled checker cannot overwrite its replacement's verdict.
Treat a human drive and a coordinator's description correction as explicit result kinds with their own provenance, preserving the existing allowed exceptions.
Have the store refuse reduced lane coverage unless it can verify the allowed unchanged surfaces, or an explicit authorized exception covers them.

Source and T3 mapping: this follows upstream swarm's refusal of results missing their promised identity and method, and `correct`'s boundary-first enforcement (`P/skills/swarm/SKILL.md:40`, `P/skills/correct/SKILL.md:19-26`).
The idea is my application of those principles to the current scripts.
`delegate_task` supplies task and child IDs; `task_status` supplies the task result; none of these calls certifies which commit the checker actually inspected.
The checker currently freezes its checkout but reads a moving `gh pr diff`; generate its review diff from the recorded commits instead (`AC/orchestrate/coordinator/templates/checker-brief.md:9-12`).

Deletes and adds: replace free-text verdict copying and about 30 to 50 lines of proof-format instructions with roughly 150 to 220 lines of schema, receipt matching and coverage checks, plus focused adversarial cases.
Keep the readable Markdown report as a rendering of the same result rather than another hand-maintained truth.

Risk and proof: schema compliance can become ceremony, and a valid JSON object still cannot prove a test ran.
Keep the schema small and retain independent execution.
On copied real rounds, demonstrate refusal of an old-head PASS, a superseded attempt, a missing acceptance item and a product-changing narrowed round, while accepting the real description-only repair and unchanged restack.

### 3. Put the whole approved merge behind one command

Problem: the agent still assembles claim, gate, merge, release, state update and notification in order (`AC/orchestrate/coordinator/skill/050-merge.md:13-34`).
The main lock is atomically acquired, but another run removes a claim solely because it is 15 minutes old (`AC/orchestrate/coordinator/bin/main.mjs:38-39`, `:163-171`).
A paused holder can later resume its remaining merge instructions after another run has reclaimed that lock.
Run 10 already showed a coordinator merging while GitHub's mergeability was still UNKNOWN (`AC/docs/plans/hzbook-run-results.md:141`).

Change: expose one `merge <run> <unit>` operation that holds an OS-backed process lock, reads current authority and main health, runs the complete gate, merges the exact approved head, reads back GitHub's result and records the merge before releasing.
Reuse the existing gate and overlap logic internally.
On restart, reconcile a merge that GitHub completed before the local recording step; do not issue a second merge blindly.
Keep `gh stack merge` for native stacks, verifying the intended heads immediately before it and reconciling its result afterward.
Document that its lack of an atomic CLI head guard remains a limitation.

Source and T3 mapping: this is my application of the deep-interface test, where callers should not coordinate several methods to complete one operation (`P/skills/architect/references/design-red-flags.md:5-15`).
T3 supplies PR links and state, but no agent-facing MCP merge operation in the studied tool surface; retain `gh` and the repository's stack workflow.
The CoS still records Bryce's exact approval using `approve.mjs`.
This changes neither his merge authority nor the approved no-wait-between-merges policy.

Deletes and adds: delete the public claim/release dance and roughly 70 to 110 lines of instructions and stale-claim handling; add roughly 100 to 160 lines of transaction orchestration and crash recovery.
The gate, approval rows and merge command remain separate internal responsibilities, with one public operation.

Risk and proof: no local lock can serialize a human merge made elsewhere, so the existing fresh-base checks and exact-head checks remain necessary.
Run two competing local merge requests and interrupt one before merge and one after GitHub accepted it.
Prove one local holder, no reusable expired claim, no widening of a shown approval, and correct recovery without duplicating the merge record.
Replay #932/#937 to ensure the folder rule still catches the actual semantic clash.

### 4. Own a small, tested T3 contract rather than scattered assumptions

Problem: several current rules misstate their dependencies.
The CoS treats `waiting` as a question (`AC/orchestrate/cos/skill/020-start.md:8`), but T3 defines it as post-turn background drain and exposes pending requests separately (`T3/apps/server/src/orchestration-v2/Orchestrator.ts:545-549`, `T3/apps/server/src/mcp/OrchestratorMcpService.ts:771-773`).
The checker launch promises that a stable request ID prevents another checker after a lost response (`AC/orchestrate/coordinator/skill/040-checking.md:12`), but T3 namespaces it by a new provider-session UUID (`T3/apps/server/src/mcp/McpSessionRegistry.ts:124-133`).
All six generated skills now have Claude's invocation flag, but the generator still emits no Codex invocation-policy sidecar (`AC/orchestrate/build.mjs:67-86`).
There is also a delivery contradiction: the Inbox section says peek, act, then acknowledge, while the CoS rules require `drain` at the start; `drain` advances the cursor before the model can act (`AC/orchestrate/cos/skill/050-inbox.md:5`, `AC/orchestrate/cos/skill/120-rules-for-you.md:7`, `AC/orchestrate/lib/inbox.mjs:117-121`).

Change: keep a small T3 adapter reference and a machine-readable list of the few relied-on capabilities, with source version, runtime and the last live probe.
Use `pendingRequestCount` and pending-request tools for questions.
Before retrying any uncertain launch after session replacement, reconcile the durable launch receipt with T3's child inventory; matching request text alone is insufficient.
Remove the agent-facing compound drain operation: peek first and acknowledge only the prefix whose effects have been recorded, so a crash replays unfinished work.
Generate `agents/openai.yaml` with `policy.allow_implicit_invocation:false` for each explicit-only skill.
Make Codex task prompts specify chunked reads with `max_output_tokens:10000` and rereads on truncation.
At each audit, inspect a stuck task's result and exact attempt even when it has written an output file; stop a leftover process before accepting the validated result or replacing the task.

Source and T3 mapping: borrow the small adapter shape and tool-name check, not a port's sync system (`PM/plugins/pstack/skills/poteto-mode/references/t3-adapter.md:25-39`, `PM/tools/check.ts:56-65`).
Codex invocation behavior is recorded in the port's probe and sidecar (`M/T3-NATIVE.md:22-23`, `M/skills/poteto-mode/agents/openai.yaml:1-2`).
Read truncation has a measured Codex reproduction (`CH/CHANGES.md:43`).
The leftover-process recovery clue comes from `TF/skills/p3-mode/SKILL.md:99`; treat it as a diagnostic clue rather than equating every completed turn with completed work, since T3 explicitly distinguishes pending child work (`T3/apps/server/src/mcp/toolkits/orchestrator/tools.ts:79-81`).

Deletes and adds: replace about 40 to 70 scattered explanatory lines with one 50-to-80-line reference, six tiny generated sidecars and roughly 100 to 160 lines of boundary checks and receipt handling.
Derive model-family identity from the actual model rather than provider-instance names, and record the actual fallback so a Claude substitute is never counted as a GPT review.
Do not vendor thousands of lines of T3 source or expect a tool-name lint to catch semantic drift such as request-ID scope.

Risk and proof: the cloned T3 HEAD may be newer than the installed app, so each behavior-changing adoption needs a probe on Bryce's installed build.
Exercise a lost launch response across a real idle release, a background waiter, a genuine pending question, an explicitly invoked Codex skill and a checker brief larger than its default read budget.
Require no duplicate task, no false human gate, a complete brief read and an unacknowledged report surviving an interrupted turn.
Whether CoS ticks actually buzz the phone and whether claude-proxy supplies usable reset times remain unproved here; measure both before using them to remove recovery mechanisms.

### 5. Review structural code quality within the existing lanes

Problem: HzBook's code review explicitly asks for correctness; its GPT lane explicitly asks for test strength (`AC/orchestrate/coordinator/templates/lanes/review.md:1-2`, `review-gpt.md:1-2`).
Snapcaster's GPT lane additionally reads repository standards, which is better, but neither shared review contract gives a concrete maintainability lens (`AC/config/snapcaster/overrides/coordinator/templates/lanes/review-gpt.md:1-3`).
The blanket in-scope rule admits acceptance failures and introduced defects, leaving a checker uncertain whether a working implementation that spreads state ownership or adds a second mechanism should block (`AC/orchestrate/coordinator/templates/checker-brief.md:31`).

Change: make one existing reviewer explicitly inspect ownership, type boundaries, duplicated mechanisms, added branching and avoidable coordination between callers.
Require a concrete explanation of the future failure or maintenance burden, with a smaller design that still meets the approved contract.
Block introduced structural regressions; buffer unrelated debt and personal style preferences.
Use file size as a signal, not an automatic 1,000-line refusal that encourages shallow extraction.
For small HzBook tickets, put this narrow responsibility into the existing GPT lane rather than adding a third reviewer.

Source and T3 mapping: adapt the useful parts of upstream's quality lens and design red flags (`P/skills/interrogate/references/code-quality-review.md:21-35`, `P/skills/architect/references/design-red-flags.md:35-57`).
Keep firstmate's rule that reviewer language cannot expand the accepted contract (`FM/.agents/skills/ask-user-authority/SKILL.md:25-37`).
The current T3 checker targets and worktrees need no change.
When successive fixes keep failing for the same design premise, ask for a new design decision before spending another round; distinguish this from independent defects that the existing rounds should fix.

Deletes and adds: replace the two-line review duty with about 12 to 18 decision-changing lines and a short shared reference; add no lane or routine panel.
Keep the existing fix-first review optimization: it is already implemented in `AC/orchestrate/coordinator/bin/brief.mjs:97-106`, despite a report recommending it as missing.

Risk and proof: a vague quality bar can recreate the run-2 hardening spiral (`AC/docs/plans/hzbook-run-results.md:21-22`).
Compare the old and new lens on one known structural regression and one clean small fix, blind to template names.
Require actionable structural findings without unrelated redesigns, and keep the live drive after a product fix.
Do not suppress singleton GPT findings: the latest pass found six solo findings among nine, all real (`AC/docs/plans/hzbook-run-results.md:363-365`), and the underlying Time Off ledger records the buffered-day and DST failures (`HZ/runs/2026-10-14-pick-any-time-and-time-off/ledger.tsv:16-18`).

### 6. Make the skills small by removing public protocol

Problem: at the fixed commit, the generated coordinator is 6,030 whitespace-delimited words and the CoS 3,763, measured from `git show 80eae9d:<path>` and splitting on whitespace.
The shared source has 4,634 lines across 66 files, including the new lessons skill.
The coordinator teaches the model storage schemas, launch syntax, manual registrations, heartbeat arithmetic, recovery and merge ordering before it can exercise judgment.
The new skill-digest check is useful damage control, but it still tells a long-lived coordinator to reread the whole skill when its machinery changes (`AC/orchestrate/coordinator/skill/080-audit-tick.md:15`).

Change: target a roughly 1,800-to-2,500-word coordinator and a 1,200-to-1,600-word CoS after proposals 1 to 4 remove protocol steps.
Keep role, authority, acceptance/proof policy and next-action workflow in the main skill.
Load restart, away, red-main and lessons details only when their condition occurs, with one explicit pointer at the relevant decision.
Put exact flags and wire formats in script help or generated launch payloads.
Derive the lane table from `lanes` instead of maintaining `text.laneTable` by hand (`AC/orchestrate/README.md:62-63`).

Source and T3 mapping: upstream says to retain only prose that changes a decision (`P/skills/poteto-mode/playbooks/authoring-a-skill.md:10`).
Firstmate's placement tree sends conditional knowledge to an on-demand owner and mechanics to the command (`FM/.agents/skills/firstmate-coding-guidelines/SKILL.md:18-35`).
This directly matches the author's advice that skills should get smaller as mechanics move into tools (`AC/docs/research/poteto-matt-pocock-interview.md:130-135`).
No new T3 primitive is needed.

Deletes and adds: aim to remove 4,000 to 5,000 words from the two entry skills, moving only genuinely conditional detail into four or five short references.
Add a word-budget check to the existing build and require explicit review of a budget increase.
Do not satisfy the budget by abbreviating commands into an unreadable wall of text or by making the model assemble two competing instruction sets.

Risk and proof: progressive loading can hide an authority boundary.
Keep merge approval, forbidden surfaces and independent proof visible in every relevant worker brief, while loading situational procedure by trigger.
Replay a cold start, a restart, an away gate and a red release with the smaller entry skills; compare actual actions, missing reads and model turns rather than claiming a speedup from word counts alone.

### 7. Separate current policy from the historical rulings log

Problem: the 484-line HzBook `rulings.md` mixes enduring boundaries, one-off approvals, superseded merge-spacing decisions and duplicate relays.
For example, the old wait-for-main ruling and the later no-wait ruling coexist (`HZ/rulings.md:133-170`), and current agents must read the log before proposing work.
The new single-writer correction will reduce duplication, but does not distinguish current authority from historical evidence.
The store is outside git; checking it as a repository fails, which establishes no local version history, not whether Bryce has some unrelated machine backup.

Change: preserve the verbatim log as cold evidence and maintain a short current-policy view with source ruling, project scope, supersession and canonical enforcer.
Keep current merge and release authority, collaborators, forbidden surfaces and temporary waivers visible; leave completed merge approvals in their run's records.
Promote durable policy into its existing project/profile/skill owner through review, then remove its repeated explanation from the hot view while retaining the original quote.
Back up the small policy, priorities and decision records privately with version history; exclude credentials, checker output and gigabytes of generated evidence.
Do not auto-expire Bryce's authority or discard an exception because it is old.

Source and T3 mapping: borrow firstmate's current-versus-cold distinction and provenance preservation, without its decay-marker system (`FM/.agents/skills/stow/SKILL.md:98-125`, `:140-154`).
T3 threads remain the source for historical conversation, not startup memory.
`brief.mjs` should render current policy and unresolved decisions from the store, and identify its generation so an old disposable CoS chat cannot silently become the active writer again.
This changes the existing read-the-whole-rulings-file rule in the skills; it preserves the verbatim capture rule and requires Bryce's review of the initial policy distillation.

Deletes and adds: remove historical rulings from routine startup and repeated session-note state; add one roughly 50-to-100-line active-policy file and a small private snapshot/restore command.
Use a budget for the combined hot brief and policy, not separate budgets that hide the total load.
Keep session notes for decisions and next intent; derive PR/run status from the live records.

Risk and proof: a summary could accidentally grant broader authority than Bryce's words.
Test a fresh CoS against the October 13/14 merge-policy changes, the no-new-follow-ups instruction (`HZ/rulings.md:418-430`), and Snapcaster's temporary local-suite waiver and later removal (`SC/rulings.md:44-71`).
Require the same current decisions, recoverable original quotes, and a successful restore into an empty scratch store.

### 8. Extend the new lessons skill with rejection, behavior checks and applied status

Problem: the newly landed lessons skill already has fixed lenses, a recurrence threshold, a structure-first ladder and real-data replay (`AC/.agents/skills/hzbook-lessons/SKILL.md:43-75`).
That closes much of the reports' self-improvement criticism.
Two gaps remain: script replay does not show that changed prose changes an agent's behavior, and a run becomes folded when a PR opens, before its proposed rules are accepted or deployed (`AC/orchestrate/lessons/skill/050-deliver.md:10-12`, `AC/orchestrate/cos/skill/080-delegating.md:29`).

Change: keep the current on-demand cadence and single lessons owner.
Give each pass a short disposition for every substantial candidate: adopted, rejected with reason, or buffered; include what old step or rule the accepted change removes.
For a claimed behavior improvement, replay one or two organic scenarios with old and new briefs, blind to their labels, and inspect the real actions or artifacts.
Distinguish a lessons PR being proposed from its changes being applied: an open PR prevents duplicate work, while only a merged and activated revision counts as folded.
Add a compact record of daily sampled PR reviews and observed post-merge regressions so the two-week trust bar can eventually be assessed from evidence.

Source and T3 mapping: upstream reflect supplies durability, decision-changing and already-covered filters (`P/skills/reflect/references/synthesizer.md:13-22`); its eval playbook supplies blinding (`P/skills/poteto-mode/playbooks/eval.md:5-23`).
Use a bounded `delegate_task` comparison only when a prose change makes a behavioral claim, not a new standing review panel for every lessons pass.
Use `t3_thread_read` on the named trial threads to inspect what happened; keep the current replay for script changes.
The proposed applied-status distinction reverses the current folded-at-PR-open convention in takeover decision 18 and the lessons delivery step, because a proposal is not yet an operating rule.
It does not reverse Bryce's ruling that per-run lessons passes are overkill.

Deletes and adds: remove roughly 10 to 20 lines that conflate proposed and applied lessons, add 20 to 35 lines of acceptance criteria and approximately 80 to 140 lines for narrow recorded scenarios and fold reconciliation.
Do not add a permanent multi-model mining hierarchy; the new skill's four lenses already cover the job.

Risk and proof: a scenario set can overfit its examples.
Keep at least one unseen case and inspect artifact behavior rather than the agent saying it followed instructions.
On the next three completed runs, require at least one rejected candidate, no duplicated existing fix, no fold credited to an unmerged PR, and a demonstrated old-fails/new-passes case for any claimed behavioral improvement.
Treat post-merge regression tracking as a prerequisite to proposing the next trust rung, not permission to merge autonomously now.

### 9. Group work by the change that should ship together

Problem: the CoS now groups independent tickets by folders to avoid rebases, but it cannot deliver a batch PR (`AC/.agents/skills/hzbook-cos/SKILL.md`, What next).
That helps collision avoidance while leaving related changes as separate units that repeatedly rebase, verify and ask for approval.
The #932/#937 failure was a semantic interaction within one run, and a shared-file-only rule would have missed it (`AC/docs/plans/hzbook-run-results.md:166-170`, `:253-256`).
Poteto's cluster advice concerns shared causes and product context, not merely selecting unrelated tasks to fit a run (`AC/docs/research/poteto-matt-pocock-interview.md:80-85`).

Change: choose the shippable change first, then map its issues to delivery units.
For one approved cluster with coupled acceptance, use one builder branch and draft PR with an acceptance checklist covering every issue, one verifier pass over the combined behavior and one approval.
Use multiple builders into an integration branch only when the changes really permit parallel ownership; run final integration proof before making its outer PR ready.
Keep independent fixes as separate PRs and keep stacks only when each layer benefits from separate review.
Do not merge unrelated work merely to reduce the number of approvals.

Source and T3 mapping: this implements an already agreed but missing batch path (`AC/docs/plans/hzbook-cos.md:47-51`, `:111`) and Bryce's one-PR-per-shippable-change preference (`AC/config/AGENTS.md:73-80`).
T3 still runs one builder child per delivery unit; the unit gains multiple issue references and acceptance items, rather than adding a new coordinator role.
GitHub remains the source of issue scope and blocking edges.
Retain the folder-overlap gate for independent PRs; Bryce explicitly kept it even after false positives (`HZ/rulings.md:211-218`, `AC/docs/plans/hzbook-run-results.md:301-304`).

Deletes and adds: generalize the unit-to-issue mapping and closure check, estimated 100 to 180 changed lines across state, briefs, evidence and tests.
For each coupled cluster this can eliminate several builder, rebase and approval cycles, but the exact saving needs a real run.
Do not add an integration branch, inner PRs or a stack when one builder can own the whole change.

Risk and proof: a large batch can conceal scope growth and delay partial value.
Pilot one small, tightly coupled epic with approved scope, and have the evidence page show each original acceptance criterion separately.
Require one coherent diff, full combined live proof, correct issue closures and no unapproved scope; compare total rounds and rebase waits with a similarly coupled prior run.

### 10. Make execution ownership real across both products

Problem: isolation by worktree has not isolated processes, databases or machine limits.
One builder killed tests by pattern and stopped the shared test database; the latest Claude hook now blocks those observed command shapes (`AC/docs/plans/hzbook-run-results.md:360`, `:389-390`).
However, the hook applies only to Claude, and treats container creation after session start as ownership, which cannot distinguish a sibling's newly created container (`AC/config/claude/hooks/shared-state-guard.mjs:19-32`).
The per-run builder cap and machine-load snapshot also do not reserve capacity across simultaneous HzBook and Snapcaster runs (`AC/orchestrate/coordinator/bin/state.mjs`, frontier; `AC/orchestrate/coordinator/bin/load-ok.sh:5-18`).

Change: keep the new hook as immediate protection, then put resource identity in the canonical environment tools: task/worktree-owned container labels, database names, browser sessions and recorded process IDs.
Shutdown should require the exact ownership identity, and test credentials should reach only the intended environment or local Stand-in.
Give heavy test execution a small shared admission limit across both projects, counted by actual running work rather than one cap per run.
Use one atomic reservation at the existing resource allocator where sharing is unavoidable; do not recreate firstmate's supervisor or quota-routing framework.
Keep model/provider fallback explicit and approved rather than silently reducing reviewer quality under load.

Source and T3 mapping: this follows upstream's one-writer/isolate-first rule (`P/skills/poteto-mode/playbooks/orchestrate.md:17`) and the author's environment-first advice (`AC/docs/research/poteto-matt-pocock-interview.md:59-68`).
Snapcaster's own rulings record reseeded shared slot volumes and the move to worktree-specific projects and owned Elasticsearch (`SC/rulings.md:50-71`).
T3 can run an idempotent shutdown hook through `runOnSettle` (`T3/packages/contracts/src/t3ProjectFile.ts:46-49`), but this does not replace shutdown before a child completes or ownership checks.
Pass the run/task identity through the generated launch brief and reconcile allocations after cancellation or restart.

Deletes and adds: replace container-age inference and repeated manual resource registration with identity-based checks, estimated 100 to 180 lines in existing environment helpers and 40 to 80 lines of shared admission bookkeeping.
Move temporary directories to task-owned disk paths; the latest replay cleanup already fixes whole-store scratch copies, so do not build that fix again.
Keep cleanup by recorded ownership and explicit refusal on dirty or unlanded work.

Risk and proof: too much resource machinery could recreate the firstmate complexity Bryce left.
Start with one resource class that already caused interference, then add admission only where simultaneous starts can exceed the actual limit.
Run a HzBook builder beside a Snapcaster live checker, stop one, and prove the sibling's process, database and browser remain usable; include a container created by the sibling after the first session began.
Repeat through child cancellation and a stale resource record without deleting another task's data.

## Radical alternative

I would rebuild the operational core around one durable run thread supervising T3 child tasks, with a disposable project CoS above it and the existing lessons skill beside it.
Keep the CoS because Bryce explicitly wants one place to talk and multiple approved runs can coexist; do not flatten it into each implementation conversation.
Keep the coordinator as the independent judgment owner, but expose fewer mechanical operations.

The run loop would be: reconcile facts, ask for the next allowed actions, make the T3 calls, record their receipts, judge results and surface only decisions or verified outcomes.
The model would write verification plans and judge scope and findings.
Code would own legal transitions, receipt identity, resource records, required proof, approval matching, merge execution and recovery.
Do not infer success from a worker ending or from a generic state mutation.

I would budget the pieces as follows, as a design estimate rather than a claim that these checks already fit:

- A 600-to-800-line state/proof module with boundary schemas, task attempts, current units, verdicts, approvals and pending actions.
- A 450-to-650-line GitHub module owning check interpretation, tested-base overlap, red-release policy and one approved merge operation.
- A 200-to-300-line launch/resource adapter producing T3 payloads, accepting receipts and cleaning only owned resources.
- A 250-to-350-line CoS module rendering the brief, pending decisions, inbox and private policy view.
- A 250-to-350-line lessons/export module, reusing the new lessons skill and its real-data replay.
- Roughly 400 to 600 lines of skill prose, templates and profiles, with entry skills inside the smaller word budgets.

That is roughly 2,150 to 3,050 non-test lines, compared with 4,634 current shared-source lines; product verification skills and focused tests sit outside both figures.
The split is by knowledge owned, not a demand for exactly six files.
Keep the current readable TSV store initially, with atomic writes and serialized shared mutations; a database migration is not necessary to achieve the simpler interface.
The important change is one supported path for each operation, not a different storage format.

T3 should own child creation, conversation, completion, cancellation and durable thread resumption.
The run should own product acceptance, verified artifacts and merge authority.
Every child gets an intended remote base or recorded PR head, because T3's isolation starts from local HEAD.
Review rounds remain fresh children; inexpensive builder follow-ups may reuse a conversation through the supported send contract.

I would keep one minimal watcher and one existing run audit schedule at first.
T3's current PR watch ends silently on merge and ignores Bryce's own comments (`T3/apps/server/src/orchestration-v2/PullRequestWatchReactor.ts:524-529`, `pullRequestWatch.ts:80-89`), so replacing it now would surrender behavior the workflow needs.
Child builders should eliminate the builder-nudge part of that watcher.
Delete the Monitor heartbeat only after an installed-build probe proves a process-independent replacement covers external merges, required base changes, quiet notification behavior and restart recovery.
A narrow signed GitHub webhook could eventually supply merge/push events, but it adds configuration and queued model turns and does not by itself replace local inbox delivery.

This remains aligned with the author's practice on independent proof, cluster-level context, buffering and moving mechanics into code.
The present drift is the amount of protocol the agent has to remember, duplicated historical memory and a learning loop that has only just gained a structure-first filter.
Mandatory human merges are an intentional trust rung, not a failure to imitate poteto; the evidence does not yet justify skipping Bryce's stated two-week bar.
No continuous intake, new area coordinators, autonomous merges or external keeper enters this rebuild without the approvals the current plans require.

## Keep

- Independent live proof and the ability to return BLOCKED when a path cannot be driven, including the API-versus-mocked distinction for Snapcaster.
- The GPT seat and its revert-and-rerun test challenge, which caught bugs the other lanes missed in runs 5, 6 and the latest Time Off work (`AC/docs/plans/hzbook-run-results.md:61`, `:74`, `:363-365`).
- Approval records bound to the PR and shown head, explicit pre-approval, and production releases staying Bryce's.
- The shared generated source with project profiles, overrides and per-run verification-policy pins; generic fixes should remain one edit across both products.
- The cross-run merge exclusion and tested-folder overlap guard, including the stronger tree-replay comparison now used for carried changes (`AC/orchestrate/coordinator/bin/lib.mjs:181-197`), even though older prose still calls it patch-id.
- The durable keyed inbox and acknowledgement cursor; T3 messages are wakeups, not the sole record of a fact.
- The new lessons skill's four lenses, structure-first ladder, project-scoped transcript packs, real-store replay and quiet automatic settling.
- GitHub as the work and acceptance source, collaborator boundaries, bounded rounds, drafts that avoid redundant CI, and cleanup by ownership.

The current system's actual refusals, approval data and real-run replay are the strongest reasons to keep it over any studied pstack port.
The useful imports are narrow engineering practices and corrected runtime facts.

## Rejected

- Replacing the workflow with a community port or upstream orchestrate: none supplies a better complete approval/proof/merge contract for Bryce, and the shared source is already tailored to the real runs.
- Restoring firstmate's supervisor, quota routing, worker pool or general fleet state: it would add another lifecycle owner beneath T3.
- Replacing the watcher with `watch_pull_request` alone: the source still lacks merge wakes and filters Bryce's own comments.
- Claiming the exact draft/required-check cause of the old CI-watch misses is settled: the observed stalls are real, but the source also resets passed state when gating checks go pending; the exact required-check set still needs a probe.
- Wiring broad GitHub check webhooks immediately: one delivery can become one model turn, without solving local fact delivery or notification semantics.
- Removing CoS or coordinator audit schedules because T3 usually resumes work: restart, provider-limit and stuck-turn gaps still need the existing backstop until measured otherwise.
- Assuming a stable `clientRequestId` gives cross-session exactly-once execution: the namespace changes with the provider session.
- Reducing review by majority vote, dropping solo GPT findings, or keeping only the live lane on small tickets: current evidence argues against weakening those checks.
- Applying upstream's automatic 1,000-line blocker or running an extra quality panel on every PR: use a concrete maintainability judgment inside existing lanes.
- Relaxing the folder-overlap rule to shared files: the one real documented semantic clash shared a folder and no file, and Bryce explicitly retained the rule.
- Mandatory fresh builders for description fixes and rebases: keep the measured reuse benefit through T3's supported child follow-up contract.
- More area coordinators, Sentry/email intake or a permanent external keeper now: these remain deferred expansions, without evidence that they solve the current delivery friction.
- Autonomous merges or shorthand-free approval flows now: they reverse Bryce's chosen authority and queue interface before the trust bar is demonstrated.
- Transcript reconstruction as CoS startup memory, automatic decay of rulings, or a vector-memory service: a short current-policy view and recoverable history solve the actual problem.
- Another recurring lessons schedule or a standing mining panel: the new on-demand lessons skill already has the right owner and cadence.
- Recommending project scoping of lesson chats, automatic settling, away-state checks, scratch-copy cleanup or the Claude shared-state hook as missing: those landed at the review's fixed commit.
- Treating a hook or a report schema as a security boundary: process/container ownership and independently executed proof still have to do the work.
