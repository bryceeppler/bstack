# Grok 4.7: how Bryce's agent workflow should improve

Read-only review, 2026-10-14.
Sources checked against the clones where a proposal rests on them.
Word counts below are from the generated skills as they stand tonight.

## Verdict

The trust in this system is already in the scripts, and the runs earned it.
Independent checkers, a live drive of the app, a second model family, a merge gate bound to a head, and a store that refuses illegal moves are why runs 5, 6 and 7 caught bugs the builder had shipped green.
Away mode decided eleven gates overnight and Bryce overturned none.
The shape around that core is what is wrong.
The coordinator is a 6,030-word incident log kept awake by a shell loop, because the skill does not trust T3 to resume a released session, and each lessons pass has added a paragraph to the log.
The chief of staff then reads that loop's side effect, a thread in `waiting`, as a question only Bryce can answer, and it re-reads 88 dated rulings, most of them one-time merge words, before it can say what to do next.
Make one change first: delete the in-session watcher and the keep-alive prose that exists to feed it, and let the audit tick plus a process-free pull-request watch carry the run.

## Proposals

### 1. Delete the in-session watcher

**Problem.**
While a run is open the coordinator keeps `watch-run.sh` running under the Monitor tool, and after 29 quiet minutes the script exits so the model can start it again (`orchestrate/coordinator/skill/090-watcher.md`).
That loop is there to stop T3 releasing the session, and to notice GitHub changes within about two minutes.
T3 already resumes a released conversation for a tick, a message, a pull-request wake and a child completion (`pingdotgg_t3code/repo/apps/server/src/orchestration-v2/ProviderTurnStartService.ts` opens the provider session with `resumeFromSession` on each dispatch).
The loop's cost is in the run record.
Run 4 spent about 20 overnight wakes re-reading the conversation, about 300k tokens a wake (`docs/plans/hzbook-run-results.md`).
Run 7 spent about 10 of 54 turns on heartbeats.
Run 9 woke every half hour for four and a half hours only to restart the watcher and repeat a list Bryce already had.
A Monitor is also why the chief of staff's picture of the work is wrong.
T3's `waiting` means the turn ended and background work still holds the thread (`agentAwareness.ts` maps `waiting` to the running phase).
The chief of staff lists `statuses: ["waiting"]` as threads stopped on a question (`orchestrate/cos/skill/020-start.md`, `030-what-next.md`), so every live coordinator ranks as the first thing waiting on Bryce.
Builders already wait on their own `gh pr checks --watch` (`orchestrate/coordinator/builder-rules.md` rule 7), and a checker's completion already wakes the parent.
The watcher's remaining unique jobs are a merge, a comment from Bryce, and the base moving.

**Change.**
`watch-run.sh` becomes a one-shot the audit tick runs.
Drop the 29-minute heartbeat and the Monitor.
Keep the tick at 20 minutes until the run's `finished` file exists, including while every unit is merge-ready, because the hourly slowdown was safe only while the watcher covered merges.
On each ready pull request the coordinator arms `watch_pull_request` and leaves it.
That watch is a process-free hold, so a finished tick does not push the phone, and it wakes on a failed check, a conflict, and a comment from someone other than Bryce.
It does not nudge a builder.
Builder rule 7 stays the CI report, because a "checks passed" wake has already fired on a draft's skipped required check and then gone quiet (`docs/plans/hzbook-run-results.md`, the 2026-10-14 runs).
HzBook's required check is now `lint` (decision 19), which makes that trap less likely, and Snapcaster may still have a heavier gate, so the watch stays a hold and a conflict signal on both projects.
A merge still ends the watch with no wake (`PullRequestWatchReactor.ts` calls `ended(target, "merged")` and posts no text).
The one-shot tick is the merge signal.
Restart treats a dead `watch.pid` as normal and reconciles from the store every tick.
The chief of staff stops reading `waiting`.
A thread needs Bryce when `t3_thread_read` shows `pendingRequestCount`, or when `inbox.mjs open` already lists a gate.

**Where it comes from.**
T3's own lifecycle, checked above, plus the run record.
The 2026-10-13 port review rejected `watch_pull_request` on the coordinator because it never reports a merge and skips Bryce's comments (`docs/plans/hzbook-pstack-takeover.md`).
That limit is still true, and this proposal uses the watch for the job it actually has: a hold and a conflict wake.
The new fact is the measured keep-alive cost, and that builders now report their own CI, which the rejection did not have.

**On T3.**
`schedule_task` interval `everyMs: 1200000`, already the audit tick.
`watch_pull_request` on each ready pull request, `unwatch_pull_request` at Finish.
`watch-run.sh --once` inside the tick, still zero model tokens until a line comes back.
No webhook.
A GitHub webhook for merges was deferred and is the right later step if 20 minutes is too slow (`schedule_task` type `webhook`, `{{body.pull_request.merged}}` only).
Each delivery is a model turn, so it suits merges and not check runs.

**Deletes and adds.**
Deletes the heartbeat, the Monitor rule, and most of Staying alive and Watcher (about 400 words, plus the incident parentheticals in those sections).
`watch-run.sh` (103 lines) loses its sleep loop and keeps the snapshot diff.
Adds a `--once` flag, one arm-the-watch step in Checking, and a rewritten start step in the chief of staff (about 30 lines of script, about 150 words of skill).
The tick interval while merge-ready goes from one hour back to 20 minutes.

**Risk and proof.**
A merge Bryce makes by hand can sit for up to 20 minutes before the next unit starts.
One HzBook run proves it: count coordinator turns against run 7's ten heartbeats, time a hand merge to the next frontier, and confirm a quiet tick does not buzz the phone.
The phone part is still a hypothesis.
Source says a completed run with no hold is a fresh completion, and a completion pushes (`agentAwareness.ts` returns `completed` when `backgroundWorkHoldsCompletion` is false; a background Bash command does not hold, a pull-request watch does).
Whether a fast tick is observed as running before it completes is unconfirmed, so the run should watch the phone for one quiet half hour before and after.

### 2. Stop making the coordinator re-read the merge log

**Problem.**
`rulings.md` is 484 lines and 88 dated sections, and both skills read it at every start (`orchestrate/coordinator/skill/010-store.md`, `orchestrate/cos/skill/030-what-next.md`).
Most sections are one approval ("merge 880", "Yes merge it") or a relay that already landed.
The durable record of an approval is already `approvals.tsv`, which `merge-ready.mjs` reads.
The standing rules (no real Outlook in local dev, a failed production release does not stop merges, away-mode terms, the lessons ladder) are mixed into the same file and have no mark that distinguishes them.
The store is outside git, so this file has no history.
A folded ruling stays in the file after the skill has absorbed it, so the next session pays for it twice.

**Change.**
Split the file.
`rulings.md` keeps standing policy: a decision that changes what a later run may do, in Bryce's words, one section each.
One-time merge words, cleanup yeses, and "go" on a queue item go to `rulings-archive.md` at the moment they are written, with the date and the run.
`approvals.tsv` remains the merge authority.
`brief.mjs` prints the size of `rulings.md`, `findings.md` and the latest session note against a budget (firstmate's `ceil(bytes/3)` is enough) and names `Lessons pass due` when `rulings.md` is over it.
The lessons skill, which Bryce approved tonight (`rulings.md`, "yes I like that idea"), gains one step: a ruling the PR encodes moves to the archive under `(folded into <file>, PR #n)`.
Copy the three small files into the lessons pack as it already does, so a lost store is a lost archive and a lost pack is the backup that exists today.

**Where it comes from.**
firstmate's stow: always-loaded memory has a budget, and a fact moves to its most specific owner and then leaves the always-loaded file (`kunchenguid_firstmate/repo/.agents/skills/stow/SKILL.md`).
Bryce's own firstmate home went over that budget once and a single pass fixed it.
pstack's position is the same in fewer words: what matters long-term is a reviewed file, and a rule drops once the mistake cannot happen (`cursor_plugins/repo/pstack/skills/correct/SKILL.md`).

**On T3.**
No new primitive.
The chief of staff still appends with the existing writer.
The archive is a file in the store.

**Deletes and adds.**
Deletes nothing from the skill except the instruction to append every explicit word to `rulings.md`.
Adds an archive file, a budget line in `brief.mjs` (about 40 lines), and one paragraph in the lessons skill.
The coordinator's start read should fall from the whole log to the standing sections, on the order of a dozen.

**Risk and proof.**
A standing rule filed as a one-time yes would disappear from the next start.
The lessons brief already requires Bryce's words under `Bryce asked:`.
Proof is a replay: `brief.mjs` on a scratch store prints the budget, the coordinator start text names the Outlook rule and the production-release rule, and a "merge it" section is absent from that text.

### 3. Cap the generated skills, and make the ladder subtract

**Problem.**
The generated coordinator is 6,030 words and the chief of staff is 3,763.
pstack's whole Orchestrate playbook is 2,692 (`cursor_plugins/repo/pstack/skills/poteto-mode/playbooks/orchestrate.md`).
Both of ours are read on every cold start, restart and tick.
The coordinator's own opening says the reasons live in the plan, and the body then retells the usage-limit outage, the draft-check miss, and the finish-on-red-main incident inline.
The lessons skill already has the right ladder: design, a refusing check, a test, and a written rule last, and a new rule deletes the one it replaces (`orchestrate/lessons/skill/030-ladder.md`).
Nothing fails when a pass adds words anyway.
That is how 20 runs became this skill.
poteto's own account is that skills are getting smaller, and that last year's skills held commands the model no longer needs (`docs/research/poteto-matt-pocock-interview.md`).

**Change.**
`orchestrate/build.mjs --check` fails when a generated `SKILL.md` grows past a committed word budget, and fails on a date (`20xx-xx-xx`) inside a skill section.
The budget starts at today's counts so the check is green, and a PR that raises it says why in the body.
The lessons skill's delivering section requires the rung, and a written-rule change names the sentence it deletes or the budget line it raises.
Incident detail belongs in `docs/plans/hzbook-run-results.md`, which already exists for that.
The first subtraction is proposal 1's watcher section, done as that lessons pass, on rung 1.

**Where it comes from.**
pstack's authoring rule: keep only prose that changes a decision (`cursor_plugins/repo/pstack/skills/poteto-mode/playbooks/authoring-a-skill.md`).
firstmate states a ceiling and never enforces it, and its contract grew from 585 to 958 lines between restructures.
Enforcing ours is the part firstmate skipped.

**On T3.**
None.
The doctor already runs the build check.

**Deletes and adds.**
Adds about 40 lines to `build.mjs` and a short test.
Deletes words only when the next pass does proposal 1 and strips the dated parentheticals.
Target after that pass: coordinator under 4,500 words, chief of staff under 3,000, with the reasons still in the plans.

**Risk and proof.**
A real judgment rule gets cut to satisfy the cap.
The budget raise is the escape, and it is visible in the PR.
Proof is the check going red on a fixture that adds a dated sentence, and the next real lessons PR showing a lower word count with `replay.sh` still passing.

### 4. Stop Codex from loading these skills by itself

**Problem.**
The four generated project skills set `disable-model-invocation: true` and ship no `agents/openai.yaml`.
Codex ignores the flag and reads the yaml (`mariusflorescu_pstack-t3/repo/T3-NATIVE.md`).
The GPT review lane runs on Codex with these skills on the skill path, so a checker can load the 6,030-word coordinator in the middle of a test review.
That lane is the one that caught the regression test which passed with the bug present (run 5) and the freshness check that refused a retry (run 6).

**Change.**
The build writes `agents/openai.yaml` with `allow_implicit_invocation: false` beside each generated skill, and the doctor fails when the flag and the yaml disagree.

**Where it comes from.**
mariusflorescu's port, which probed Codex and linted the pair (`mariusflorescu_pstack-t3/repo/scripts/check-t3-native.mjs`).
The brief's orchestrator check confirmed our four skills lack the file.
pmwoz does the same sidecar in its sync transform.

**On T3.**
No runtime tool.
Codex reads the file from the skill directory.

**Deletes and adds.**
Adds four yaml files, generated, and about 20 lines in `build.mjs`.
Deletes nothing.

**Risk and proof.**
Low.
A Codex thread that should invoke the skill by name still can, because the yaml blocks implicit invocation only.
Proof is the doctor failing when the yaml is removed, and one GPT checker brief whose thread does not show the coordinator skill loading.

### 5. Judge structure, and stop a same-theme round

**Problem.**
The review lane judges correctness against the acceptance criteria (`orchestrate/coordinator/templates/lanes/review.md`).
The GPT lane judges tests (`review-gpt.md`), including the revert-and-rerun check that caught run 5.
Nothing in either lane mentions file size, a second way to do one task, a new branch in a shared flow, or a cast where a type would do.
Bryce's priority is code quality, and the next agent copies whatever lands.
The brake matters as much as the lens.
Run 2 spent five review rounds, and the later ones hardened past the acceptance criteria.
Run 10's documentation ticket took four rounds on one claim.
firstmate's #714 took 15 rounds, and every "also add" was later reversed (`~/git/firstmate` captain notes, cited in the firstmate report).
The round cap is the only stop, and it arrives after the rounds are spent.

**Change.**
Add a short approval bar to the review lane, taken from pstack's code-quality review and cut to the items that are presumptive blockers there: a file pushed from under 1,000 lines to over, a new ad-hoc branch in a shared flow, a second implementation of something the repo already has, and a cast or `any` where the neighbouring code has a type (`cursor_plugins/repo/pstack/skills/interrogate/references/code-quality-review.md`, the Approval Bar).
Anything else the checker admires, including a "code judo" restructuring, is a follow-up issue, not an in-scope finding.
Give the GPT lane the weak-assertion list from `principle-test-behavior-not-implementation` as extra things to try, beside the revert-and-rerun it already does.
When a round's in-scope finding shares a file and a theme with an earlier round, the coordinator parks a gate in five parts (the requirement, the expansion, the smallest change that meets the requirement, the consequence either way, the recommendation) instead of opening the next fix round.
`state.mjs verdict` prints `repeat-theme` when the same path appears again, and the coordinator judges it.

**Where it comes from.**
pstack's lens and its architect red flags, narrowed so they cannot recreate run 2.
firstmate's ask-user authority, which escalates a repeated theme that is preserving a design rather than closing a defect (`kunchenguid_firstmate/repo/.agents/skills/ask-user-authority/SKILL.md`).

**On T3.**
The same `delegate_task` checkers, `isolation: "worktree"`.
The gate already posts to the inbox and reaches Bryce through the chief of staff.
No new tool.

**Deletes and adds.**
Adds about 40 lines across the two lane templates and about 15 lines in `state.mjs`.
Deletes nothing.
Follow-ups use the existing `needs-triage` path.

**Risk and proof.**
The bar still starts rounds Bryce would have skipped.
One standard ticket is the proof: count in-scope structural findings against follow-ups, and see whether Bryce accepts the in-scope ones on the evidence page.
If the first two runs produce only follow-ups, keep the bar and do not promote it.
If a same-theme gate fires and Bryce takes the smallest change, the brake worked.

### 6. Make builders child tasks, once the tick-only coordinator has one clean run

**Problem.**
Builders are top-level threads (`t3_thread_launch`) that report by messaging the coordinator, and the coordinator judges them alive by side effects because a thread can end without a report (run 10).
The port review rejected `delegate_task` for builders because delegation had no worktree (`docs/plans/hzbook-pstack-takeover.md`).
That reason is stale.
`delegate_task` now takes `isolation: "worktree"` (T3 commit 25629a76, already how checkers run).
A follow-up `t3_thread_send` to a finished child's `childThreadId` starts a fresh task in that thread and wakes the parent (`pingdotgg_t3code/repo/apps/server/src/mcp/toolkits/orchestrator/tools.ts`, the `t3_thread_send` description).
The injected line that says not to send to `childThreadId` is about a delegated review round (`orchestrationInstructions.ts`), which is the case the tool tells you to open with a new `delegate_task`.
`ports-b.md` treats that line as a ban on continuing a builder.
The orchestrator check in the brief, and the tool text, say the opposite.
Run 7's saving, documentation fixes sent back to the same builder, still works under that send.
Children never push the phone (`agentAwareness.ts` returns null for a subagent).
A top-level builder that ends on a background `gh pr checks --watch` can, because a background command does not hold completion.

**Change.**
After proposal 1 has one clean run, launch each builder with `delegate_task`, `isolation: "worktree"`, `mode: "async"`, the same brief path it gets now.
A fix round, a description fix, and a rebase are a `t3_thread_send` to that `childThreadId`, which is the reuse run 7 measured.
Completion is the report, so "pushed and ended without reporting" cannot be the silent case it was in run 10.
`liveness.mjs` shrinks to the hung turn, which T3 still does not reap.
The brief keeps `git fetch && git reset --hard origin/<base>` and the branch name, because the worktree starts at the coordinator's HEAD on a `t3/<hex>` branch.
Restart stays in the same thread, which is already the tick's `bindToCurrentThread` path, because `task_status` cannot see another parent's tasks.

**Where it comes from.**
T3's tool contract, the stale rejection, and probe 8 (a checker child outlived the parent's idle half hour and woke it).
pmwoz maps a writing lane to `isolation: "worktree"` (`pmwoz_t3-pstack/repo/plugins/pstack/skills/poteto-mode/references/t3-adapter.md`).

**On T3.**
`delegate_task` as checkers already use it.
`t3_thread_send` with `mode: "queue"` and a fresh `clientRequestId` per fix.
`task_cancel` before a replacement, then confirm the task is terminal, so two builders never push one branch.
Bryce can open the child thread.
The server and the composer allow typing into an app-owned child; the user doc still says agent-started subagent threads cannot take messages, which matches provider-native subagents only.
Treat "Bryce can steer a builder by typing" as something the trial run confirms.

**Deletes and adds.**
Deletes builder `t3_thread_launch`, the report-by-message step, `thread.id` retargeting for builders, and the "ended without a report" branch of liveness (about 200 words, and the launch branch in `brief.mjs`).
Adds the child launch settings `brief.mjs` already prints for checkers.
Net skill size down.

**Risk and proof.**
Settling or archiving the coordinator drops queued child completions.
Finish already settles last, and proposal 1's tick is what keeps the thread resumable until then.
A child cannot call `watch_pull_request`, which this design does not need, because proposal 1 leaves watches on the coordinator and CI waits on the builder's own `gh pr checks --watch`.
Proof is one small ticket: the builder's completion wakes the coordinator with the report, a description fix goes back to the same child and wakes again, and Bryce can open that thread and read it.

### 7. Recover a checker that finished and left a process up

**Problem.**
The audit tick calls a checker stuck only when its output folder has gone quiet (`orchestrate/coordinator/skill/080-audit-tick.md`).
A checker that wrote its verdict and then exited with a process still running has a new file, never completes, and never wakes the parent.
Tr1Fecta measured the signature: `workState: "waiting_for_children"` with `latestTerminalStatus: "completed"`, and the report is lost (`Tr1Fecta-7_p3-stack/repo/CHANGES.md`).
The same note says each half of the fix fails alone: an agent rule left the parent waiting, and a parent rule stopped the process in 2 of 5 runs.
We took the prevention (stop processes before reporting) and not the recovery.
Run 8 left `playwright-cli` sessions holding removed worktrees.

**Change.**
On each tick, for every checker still running, read `task_status`.
When the verdict file is present, or the task shows that signature, record the verdict and `task_cancel`.
`task_cancel` stops the leftover process.
The existing `--attempt` path covers a verdict that is missing after the cancel.

**Where it comes from.**
Tr1Fecta's measured harness bug, confirmed as a T3 state by their trial, and our audit tick's gap.

**On T3.**
`task_status` and `task_cancel`, both already used.

**Deletes and adds.**
Adds about 20 lines to the audit-tick section and a branch in whatever script the tick is told to run, if the judgment moves into `liveness.mjs`.
Deletes nothing.

**Risk and proof.**
Cancelling a checker that is still writing the verdict.
Require the verdict file to contain the verdict line before cancel, which proposal 8's parser can share.
Proof is a scratch child that writes a verdict and sleeps: the next tick records it and the task ends.

### 8. Treat a request id as session-scoped

**Problem.**
The coordinator says a retry with the same `clientRequestId` starts no second checker (`orchestrate/coordinator/skill/040-checking.md`).
The id is scoped to the provider session (`McpSessionRegistry.ts` sets `requestNamespace` to a fresh session id).
A retry after an idle release or a restart creates new work.
The brief's orchestrator check confirmed this.
Two checkers on one branch is the failure the attempt counter was built to prevent.

**Change.**
Before any checker or builder launch, the script looks for the task id already recorded in `created.tsv` for that unit, round and lane.
A live one is waited on.
A missing one is launched, and the attempt number comes from the rows, not from the model's memory.
The skill sentence that promises cross-session dedupe goes away.

**Where it comes from.**
T3's session registry, and the skill sentence that overclaims it.

**On T3.**
`created.tsv` is already the record.
`task_status` confirms the recorded id when the parent thread is the same one.

**Deletes and adds.**
Adds a lookup of about 30 lines beside the launch printer in `brief.mjs`.
Deletes one misleading sentence.

**Risk and proof.**
A scratch store with a recorded task id must print "already launched" and exit without a second `delegate_task`.
Replay on a real run folder that has task rows is the test.

### 9. Put the merge gate on the commit

**Problem.**
`merge-ready.mjs` is strong and it is a script the coordinator remembers to run.
A merge from the GitHub UI, or from a thread that skips the script, never sees it.
Run 11's stack layer got a hand-made PASS when the gate failed, which is the same shape: the gate is advice until something outside the model requires it.
Decision 3 still has Bryce click every merge, so the hole is whoever clicks outside the coordinator.

**Change.**
When `merge-ready.mjs --merge` exits 0, post a commit status `orchestrate/verified` on that head with `gh api`.
Add that context to the ruleset's required checks beside `lint`.
A status post starts no workflow, so it does not add a billed suite run.
A new head has no status until the gate passes again, which is the patch-id rule in a form GitHub enforces.
The coordinator's squash merge already uses `--match-head-commit`.

**Where it comes from.**
firstmate's required attestation, which is a body claim a job checks, weakened because the body can lie (`kunchenguid_firstmate/repo/CONTRIBUTING.md`).
A status on the commit is the stronger form of the same idea, and it matches pstack's `correct`: the highest rung that works.

**On T3.**
`gh`, which the coordinator already uses to merge.
No MCP merge exists, and this does not add one.

**Deletes and adds.**
Adds about 40 lines in `merge-ready.mjs` and a profile slot for the status context.
Deletes nothing.
The ruleset edit is one GitHub change per repo, named in the PR for Bryce to apply.

**Risk and proof.**
A ruleset change that blocks a human merge Bryce wanted in a hurry.
The status is posted only after the gate he already trusts, and he can remove the context from the ruleset in one step.
Proof is a scratch pull request: the gate's pass posts the status, a new commit clears it, and `merge-ready.mjs` fails closed when the status is absent.
Do this after proposal 1, so the tick is what posts it when Bryce approves while the coordinator is idle.

## Radical alternative

Rebuild the same trust with one thread Bryce lives in, one thread per run, and the scripts that already refuse bad states.

The scripts stay.
`state.mjs` (473), `main.mjs` (295), `merge-ready.mjs` (215), `brief.mjs`, `inbox.mjs`, `approve.mjs`, `evidence.mjs`, `cleanup.sh` and `lessons.mjs` are about 3,500 lines and they are the product.
No port and not upstream pstack has a merge gate, a cross-run main lock, and approvals as rows.
Cutting them would trade away the part the runs showed was right.

The coordinator skill is about 1,200 words.
Start from the store, launch children, record verdicts, run the gate, merge, finish.
The audit tick is one section of about 150 words: reconcile, one-shot the snapshot, recover a held checker, start anything `frontier` allows.
There is no Staying alive section and no Watcher section.
Builders and checkers are `delegate_task` children in worktrees.
The coordinator arms a pull-request watch per ready PR and never keeps a process.

The chief of staff skill is about 900 words.
Read `brief.mjs`, recommend one action, queue writes until `go`, drain the inbox, write `away.md` when he leaves.
It does not launch coordinators' builders, does not poll, and does not read `waiting`.
Its tick is 30 minutes only while a run is unfinished, and the phone question from proposal 1 is settled before that tick stays.

The lessons skill stays near its current 1,630 words.
It already is the self-improvement loop, with four lenses and the structure ladder, and the only addition is the word budget and the rulings archive step.

`rulings.md` is standing policy under about 150 lines.
Lane templates are the three that exist, plus the short structural bar.
Builder rules stay a pasted list only for the lines that are judgment (apply the default and keep going, file an "also add").
Lines a script or a hook can refuse (pattern kills, ending a turn without a report, a verdict with no head) leave the paste.

Total always-loaded prose is about 4,000 words across the three skills, against about 11,400 now.
The run Bryce feels is the same: three to five tickets, a live drive, a GPT look at the tests, an evidence page, his merge, a lessons pass when three runs have finished.
The difference is that a quiet hour costs one short tick and no heartbeat, and a new incident becomes a refusing check or it stays in the results file.

## Keep

These are the parts a swap to pstack, firstmate, or a port would drop, and the runs say to hold them.

- The refusing store, the merge gate, the cross-run main lock, and approvals tied to a head.
  No reviewed framework has them.
  They are what stopped a relayed "merge them" from covering a pull request Bryce had not been shown, once the row replaced the relayed words.
- Checkers who did not write the change, a live drive through `verify-hzbook`, and one GPT seat on the tests.
  Runs 5, 6 and 7 are the evidence, and the GPT seat was the only one that saw two of those bugs.
- Draft pull requests until code-ready.
  Decision 4 exists to keep CI off the draft, and opening ready was already rejected for that reason.
- Replay of changed scripts on a real store before a lessons PR.
  Fixtures alone missed the cancelled-run bug in run 11.
  firstmate has no retro loop at all.
- The shared source and the per-project profile, with the run's lanes pinned at init.
  A skill edit mid-run cannot add a lane to a unit already approved.
- Away mode as a file the coordinator reads, with defaults Bryce can overturn.
  Eleven gates, none overturned, is the trust measurement.
- The inbox as the record and the message as a doorbell, with a key so a replay posts once.
  T3's queue does not give you that across a dead thread.
- Bryce still merging, until decision 3's bar is actually met.
  Two pull requests each green on their own broke main together (#932 and #937).
  poteto merges while she sleeps because verification earned it.
  Ours has not, and the gate is the honest hold.
- The lessons skill as it stands tonight.
  It is the small skill the older two should become, and it already says a written rule is the last rung.

## Rejected

- Tracking any of the five ports, or taking their sync tooling.
  Already rejected on 2026-10-13, and nothing since adds a merge gate worth the machinery.
- `recall` as the chief of staff's memory.
  Already rejected.
  The store and `brief.mjs` are the memory, and proposal 2 makes that read smaller.
- Climbing the trust ladder now, or Autopilot-full's owner merges.
  Decision 3, and the #932 clash is the fact that says the bar is unmet.
- `watch_pull_request` as the only merge signal.
  A merge ends it with no wake, checked in `PullRequestWatchReactor.ts`.
- A fresh child for every description fix.
  Already rejected.
  Run 7 saved about an hour and twenty minutes by reusing the builder, and proposal 6 keeps that reuse.
- Opening pull requests ready.
  Decision 4.
  It spends the suites early, which HzBook's CI-cost work just finished removing from the pull request.
- firstmate's watcher, wake classifier, supervision branch and harness adapters.
  That is the machinery Bryce left, and T3 is the runtime.
- A second lessons process, a reflect panel on every pass, or a blind eval harness.
  The lessons skill Bryce approved tonight is the loop.
  Adding miners on top of it is the bloat he already called overkill.
- The full code-judo review as an in-scope finding.
  It would recreate run 2's extra rounds.
  Proposal 5 keeps only the structural bar, and the rest is a follow-up.
- Reviewing only the fix diff on later rounds, as a blanket.
  Run 7's later rounds found further real defects in the new tools.
  The live lane still drives the named flow.
- Ten live lanes, a perf lane on every pull request, and mandatory arena for ordinary features.
  One live lane plus the GPT tests seat is the cost that has earned its place.
- The session-start hook, `make-bot-ui`, thread fork and merge-back, and `t3_thread_wait` in the chief of staff.
  Already rejected or deferred, and this review found no new fact that changes them.
- A `hold.md` beside `away.md`.
  Deferred, and away mode plus `main.mjs claim` already stops merges.
- Sentry and client-mail intake, and Benny's two-stage repro.
  The plan is right to wait until verification has earned unattended merges.
- A GitHub webhook per check run.
  Each delivery is a model turn.
  The builder's `gh pr checks --watch` costs none.
- Per-spawn model choice.
  `models.json` printed by the script is stronger, and a Fable chief of staff cannot spend the Fable allowance on a run.
- Cloud agents and a VM per worker.
  The work runs in worktrees on one machine, and `load-ok.sh` is the cap that machine needs.
- Porting pstack's `orch` store or `watch-pr`.
  `state.mjs` is about a quarter of `orch`, and proposal 1's one-shot script covers the events `watch-pr` would.
