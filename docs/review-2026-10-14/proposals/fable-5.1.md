# How Bryce's agent workflow should improve: Claude Fable 5.1

Read-only review, 2026-10-15.
Paths without a prefix are relative to `/home/bryce/git/agent-configs/` at commit 80eae9d (PR #71 merged while this review ran, so the lessons skill and the shared-state hook are counted as present).
`STORE/` is `~/.claude/orchestrate/hzbook/`; `T3/` is `/tmp/agent-research/pingdotgg_t3code/repo/`; `U/` is `/tmp/agent-research/cursor_plugins/repo/pstack/`.
Every T3 and pstack claim this proposal rests on was read in the clone, not only in the reports.

## Verdict

The trust in this system comes from its scripts, and that part is right: `state.mjs` refuses illegal moves, `merge-ready.mjs` ties every verdict to a head and a patch id, `main.mjs` serializes merges across runs, approvals are rows, the inbox is a keyed record with a doorbell, models and policy are pinned in data, and the lessons pass now replays scripts on real stores and climbs an enforcement ladder; none of pstack, firstmate or the five ports has a merge gate, a main lock or a refusing store.
The checker lanes earn their seats: across every run the GPT lane returned in-scope issues in 21 of 49 verdicts, the Claude review in 14 of 51 and the live lane in 18 of 91, and on 2026-10-14 all six solo GPT findings were real.
What is wrong is the shape around that core: the trust lives in about 3,900 lines of scripts, but the bulk lives in prose, 6,030 words for the coordinator and 3,763 for the chief of staff, re-read at every tick and restart, and the 2026-10-14 runs show agents breaking rules the text already held (builder rule 11 twice, the no-message heartbeat rule 39 times out of 41, the away-mode rule at 96 minutes).
Roughly a third of the coordinator's prose and three of its scripts exist only to keep a session alive and to relay facts between threads: the Monitor-held watcher, the 29-minute heartbeat, the audit tick's revival steps, the Restart section, `liveness.mjs`, the builder report message and the `cos.id` doorbell.
T3 needs none of it: it resumes a released conversation on every wake, and a child task's completion is a durable wake that carries the result (`T3/apps/server/src/orchestration-v2/ProviderTurnStartService.ts:531-549`, `OrchestratorMcpService.ts:2054-2057`).
Builders are the one actor in the tree that is not a child task, and that single exception is what the watcher, the liveness judge and the report protocol paper over.
The first change: make builders `delegate_task` children of the coordinator in their own worktrees, exactly like the checkers, and delete the session-keeping layer that exception required.
Bryce already ruled this direction for Snapcaster on 2026-10-14 ("they can be the subagent t3code threads that we can read and inspect but not send messages to", `~/.claude/orchestrate/snapcaster/rulings.md:62`), and the plan's reason for rejecting it ("no worktree option", `docs/plans/hzbook-pstack-takeover.md:150` and `:187`) is stale since T3 commit 25629a76.
After that, put the skills on a build-enforced word budget, so every future lesson that adds a rule must delete one, and let the coordinator merge small tickets, which decision 3 already promised once the record was clean.

## Proposals

### 1. Builders become child tasks, and the session-keeping layer goes

**Problem.**
A builder is a top-level thread, so its end does not wake the coordinator; everything else in the run is a child or a script.
That one gap produced the watcher under a Monitor with a 29-minute heartbeat (`.agents/skills/hzbook-coordinator/SKILL.md:163-212`), `liveness.mjs` (117 lines) to guess whether a builder is alive, the Restart section, and the builder's "message the coordinator with your report" protocol.
The cost is in the record: run 10 "one builder pushed a fix and ended its turn without reporting; the audit tick caught it an hour later"; run 11 the same for #810; on 2026-10-14 builders idled 81 to 96 minutes after CI was green; the CI-train run had 57 routine wakes and its coordinator answered 39 of 41 heartbeats with a message the skill forbids (`docs/plans/hzbook-run-results.md:368`).
The four skill sections that exist for this (Staying alive, Audit tick, Watcher, Restart) are 1,317 words of the coordinator's 6,030.

**Change.**
`brief.mjs builder` prints a `delegate_task` call instead of a `t3_thread_launch`: `target` from the `builder.*` phase of `models.json`, `isolation: "worktree"`, `mode: "async"`, `clientRequestId` `<run>-<unit>-r<round>-a<attempt>`, `task` "Read <brief path> in full and follow it".
The brief keeps its first step as `git fetch origin && git reset --hard origin/<base>` and `git switch -c <branch>`, because a child worktree starts from the coordinator checkout's local HEAD on a `t3/<hex>` branch (`T3/packages/shared/src/git.ts:15`).
The builder's report is the task result plus the report file; its completion wakes the coordinator with that result, so "pushed and ended without reporting" cannot happen.
A fix round, a description fix or a rebase is a `t3_thread_send` to the `childThreadId` with `mode: "queue"`: T3 starts a fresh task in that child thread and notifies the parent when it ends (`T3/apps/server/src/mcp/toolkits/orchestrator/tools.ts:238`, checked by the orchestrator), which keeps run 7's 1h20 saving from reusing the builder.
The builder still waits on CI with its background `gh pr checks --watch`; a background command is a roster entry that pins its session (`T3/apps/server/src/orchestration-v2/Adapters/ClaudeAdapterV2.ts:2052-2072`), the same as today.
The coordinator's tick becomes hourly and runs only while a child task is live or a unit is queued: it runs `state.mjs reconcile` for merges made outside the run, `state.mjs skill`, and a hung-task check (`task_status` on a task past twice its timebox with no new push, then `task_cancel` and `--attempt 2`, the rule checkers already have).
When every unit is merge-ready, merged or blocked, the coordinator has no tick and makes no turn until the chief of staff's approval line wakes it, so an idle coordinator never pushes Bryce's phone.

**Where it comes from.**
T3's own design: "the more of our run that is a delegate_task tree under the coordinator, the more of T3's recent hardening we inherit" (child questions, isolation, restart delivery, cancellation cascades; `T3/apps/server/src/orchestration-v2/DelegatedTaskQuestionReactor.ts`, commit 25629a76).
pstack's orchestrate playbook has the same rule: "Completions are queue events, not interrupts" (`U/skills/poteto-mode/playbooks/orchestrate.md:9`).
Bryce's Snapcaster ruling of 2026-10-14 asks for it.

**T3 mapping.**
`delegate_task` with `isolation: "worktree"`, `t3_thread_send` to the child for later rounds, `task_status` and `task_cancel` for the hung case, `t3_thread_list` with `parentThreadId` to find a run's children after a restart, `schedule_task` hourly for the tick.
Children never push the phone (`T3/packages/shared/src/agentAwareness.ts:62`), and their running turns hold the coordinator's own completion push, so Bryce hears only from the chief of staff, which is what he asked for.

**Deletes and adds.**
Delete `watch-run.sh` (103 lines), `liveness.mjs` (117), the Monitor and heartbeat rules, the Watcher and Staying alive sections, Restart down to five lines, audit tick steps 1 to 3 and 5, the `thread` rows of `created.tsv`, and the builder's "message the coordinator" paragraphs (about 1,300 words and 220 script lines).
Add about 30 lines to `brief.mjs` and 15 to the skill.

**Risk and proof.**
A child cannot `watch_pull_request` (not used), a settled or archived coordinator drops queued completions (Finish already settles last), and a fresh-thread restart cannot read another thread's tasks, so restart stays in-thread through the tick, as today.
Whether Bryce can type into a child thread is unconfirmed in the UI, though the server allows it (`T3/apps/web/src/components/ChatView.tsx:2144`); his Snapcaster ruling accepts read and inspect only.
Proof is one run of three to five units with no heartbeat turn: coordinator turns per unit-hour against run 6 (20 in 2 hours) and the CI-train run (57 routine wakes), zero "ended without a report" findings, and the time from CI green to the coordinator's next action under five minutes.

### 2. A word budget on the generated skills, enforced by the build

**Problem.**
The coordinator skill is 6,030 words and the chief of staff 3,763, against 2,692 for pstack's whole Orchestrate playbook, and both carry dated incidents the skill's own line 12 says live in the plan (`.agents/skills/hzbook-coordinator/SKILL.md:177-179`, `:203-205`, `:226`).
Every lessons pass since 2026-10-10 added prose, and the 2026-10-14 pack shows the limit of prose at this length: 39 of 41 heartbeats answered against the rule, builder rule 11 broken twice, rulings appended 16 times after a ban.
The new lessons skill writes rules last, but nothing makes it delete.

**Change.**
`build.mjs --check`, which the doctor and CI run, fails when a generated SKILL.md passes a committed budget (coordinator 3,000 words, chief of staff 2,000, lessons 1,500) or when a skill section contains a date or a quoted ruling; the budget may rise only by a PR line that says why.
Situational sections (Red main, Away, Restart, Finish, Triage, Findings) move to `references/<name>.md` beside the skill with one trigger line each, which Claude and Codex both read by path; incidents and rulings move to the plan and `rulings.md`.
The lessons skill's rung 4 gains one sentence: a written rule it adds names the words it deletes.

**Where it comes from.**
pstack: "When in doubt, delete. Keep only prose that changes a decision. Tell it to do the thing and skip the reason" (`U/skills/poteto-mode/playbooks/authoring-a-skill.md:10`) and reflect's rule to drop drifting detail (`U/skills/reflect/references/synthesizer.md:24-34`).
firstmate wrote a 9,000-word ceiling after its contract grew from 585 to 958 lines and never enforced it (`/tmp/agent-research/kunchenguid_firstmate/repo/.agents/skills/firstmate-coding-guidelines/SKILL.md:15`); enforce ours.
Codex's 3,000 to 6,000 token read budget (checked by the orchestrator) is another reason the files must be small.

**Deletes and adds.**
About 3,500 words of prose across the two skills; 40 lines in `build.mjs` and one test.
No T3 primitive is involved.

**Risk and proof.**
A trigger-loaded section costs one read when it fires; that is cheaper than carrying it on every turn.
Proof is the next lessons pass landing with a net negative word count and the pack's rules-against-reality lens reporting fewer broken text rules.

### 3. Rung 2 of the trust ladder now: the coordinator merges small tickets

**Problem.**
Decision 3 (`docs/plans/hzbook-pstack-takeover.md:26`) promised self-merge for `complexity:small` after about two weeks of clean verdicts and no post-merge regressions.
The record since 2026-10-06 meets it: every small unit merged, and the one post-merge break (#932 and #937) was two standard units that the folder-overlap rule now covers.
The remaining wait on a verified small PR is the human: on 2026-10-14 i923, i963 and i941 waited 60, 68 and 117 minutes between merge-ready and merged while Bryce was away (`STORE/runs/*/moves.tsv`), and Bryce said "I just hate having 4 small fixes and having to wait 90 mins to get them on staging. That is a bottleneck for us right now" (`STORE/rulings.md:164`).
A merge releases staging only (decision 19), so the blast radius is bounded.

**Change.**
`approve.mjs policy small` writes one standing row in the store from Bryce's words; `merge-ready.mjs --merge` accepts it for a `complexity:small` unit whose every lane is PASS at the head and whose local gate passed, and `main.mjs claim` treats it like any approval, away mode included.
The chief of staff still receives the merge-ready and merged rows and shows the evidence page afterwards; a re-label to standard (already recorded by `state.mjs set`) voids the standing row for that unit.
Production stays Bryce's on every rung.

**Where it comes from.**
poteto's ladder: "Agents merge while she sleeps, and she reviews the commit history in the morning" (`docs/research/poteto-matt-pocock-interview.md`, Let agents merge); our own decision 3 and the target design's rung 2 (`docs/plans/hzbook-agent-workflow.md`, Merge and release).

**T3 mapping.**
None new: the gate and `gh pr merge --match-head-commit` already exist; only the approval source changes.

**Deletes and adds.**
About 30 lines across `approve.mjs` and `merge-ready.mjs`, one line in the coordinator's Merge section, and the trust bar result written into decision 3.

**Risk and proof.**
A mislabelled small ticket; the live lane and the GPT lane still gate it, and `complexity:small` already means single-concern with clear seams.
This reverses no ruling; it executes one, and Bryce decides the date.
Proof is two weeks: small merges without his click, post-merge reverts (target zero), and the summed merge-ready wait saved.

### 4. The Claude review lane judges code quality, so the two review lanes stop overlapping

**Problem.**
`review.md` is two lines of correctness (`orchestrate/coordinator/templates/lanes/review.md`) and `review-gpt.md` is tests, so no lane judges structure, file size, branching growth, duplicated helpers or type discipline, which are Bryce's stated priorities (`config/AGENTS.md`: simplicity, "any is the enemy").
The data says the Claude review lane is the weakest seat: 14 of 51 in-scope against the GPT lane's 21 of 49, and on 2026-10-14 three rounds were opened by GPT findings alone.
Nothing in the system measures code quality, so nothing can get worse visibly.

**Change.**
Copy pstack's Dimensions and Approval Bar (`U/skills/interrogate/references/code-quality-review.md:21-43`: code judo, the 1,000-line rule, spaghetti branches, boring code over magic, type and boundary cleanliness, the canonical layer) into `orchestrate/coordinator/templates/lanes/review-quality.md`, read by path from `review.md`.
Only approval-bar items are in-scope findings; the rest are follow-ups, so round counts do not balloon.
For Snapcaster, where the GPT lane already reviews full correctness, the Claude lane becomes quality first.

**Where it comes from.**
pstack's interrogate lens, which is the one thing pstack checks that this system does not.

**Deletes and adds.**
One reference file of about 40 lines, three lines in `review.md`; no new T3 primitive.

**Risk and proof.**
More ISSUES rounds at first, bounded by the approval bar.
Proof is the next pack showing structural findings from the review lane that were not dismissed, and a review lane hit rate that stops duplicating the GPT lane's.

### 5. Memory: rulings hold policy only, folded rulings are archived, and the store gets a history

**Problem.**
`STORE/rulings.md` is 484 lines, read by both skills at every start, and most of it is one-off approvals ("merge 880", "Merge it", "ok i updated the github actions budget" three times) that `approvals.tsv` and the inbox now carry; "most rulings that day appear twice" because coordinators and the chief of staff both appended (`docs/plans/hzbook-run-results.md`, 2026-10-14 results).
The chief of staff skill still says a merge word is appended to `rulings.md` (`.agents/skills/hzbook-cos/SKILL.md:131`), which is the duplicate.
The store has no git history, so a bad edit to priorities, findings or rulings is unrecoverable, and a folded ruling is paid for twice: once in the skill, once at every start.

**Change.**
Approvals, merge words and operational fixes never enter `rulings.md`; `approve.mjs` and the inbox are their record, and the chief of staff rule at line 131 changes to say so (this amends a 2026-10-13 rule, with the fact that approvals became rows on 2026-10-14).
`rulings.md` holds standing policy, one dated line each; the lessons pass moves each ruling it encodes to `rulings-archive.md` with `(folded: <file>, PR #n)`, and the lessons PR lists every move.
`brief.mjs` prints a token estimate of rulings, findings and sessions (bytes over three, firstmate's measure) and flags a lessons pass due above 3,000.
`store.mjs init` runs `git init` in the store, and `store.mjs note` and the lessons fold commit, so memory has a history without coupling the store to agent-configs.

**Where it comes from.**
firstmate's stow budget and archive with provenance (`/tmp/agent-research/kunchenguid_firstmate/repo/.agents/skills/stow/SKILL.md:120-154`, `bin/fm-startup-memory-budget.sh`); pstack's "Drop a rule once its mistake can't happen" (`U/skills/correct/SKILL.md`, Keep the rule table).

**Deletes and adds.**
Rulings shrink to under 100 lines; about 40 script lines.

**Risk and proof.**
Archiving a ruling that was only half encoded; the archive keeps the words and the PR names each move.
Proof: no ruling re-asked in the next two weeks, and a smaller coordinator start read.

### 6. The doorbell is the tick, not a thread id

**Problem.**
`cos.id` changes with every chief of staff chat, and the run results record the cost: a merge report sent to the old chat so the new one said the merge was still to come, a session note "new CoS must tell all live coordinators its thread id", and a plan-mode sender refused by the mode ceiling.
PR #63's fix (read `cos.id` at every send) still depends on the new chat writing it before anyone rings.

**Change.**
The inbox scripts print `run_scheduled_task_now <tick.id>` as the doorbell whenever the store holds a tick, and the `t3_thread_send` only as a fallback.
T3's handler requires only a full-access caller and that the task exists (`T3/apps/server/src/mcp/toolkits/thread/handlers.ts:79-95`), and a bound tick dispatches its prompt as a queued message to whichever thread it is bound to (`ScheduledTaskService.ts:815-831`), which a new chat already rebinds at Start.
The tick's prompt is the drain, so the address never changes across chats; a manual run while a tick is running errors "already running", and the row waits for that drain, so nothing is lost.
The interval falls to 60 minutes as the fallback for a lost doorbell.

**Where it comes from.**
Our own housekeeping candidate (`docs/plans/hzbook-pstack-takeover.md`, Port review: "`run_scheduled_task_now` on a run's tick as status now"), turned around to point at the chief of staff.

**Deletes and adds.**
`cos.id` relays and the "tell every live coordinator the new id" step go; about 10 lines in `inbox.mjs`.

**Risk and proof.**
Each manual run counts in `runCount`, and a tick is required while anything is live, which is already the rule.
Proof: start a fresh chief of staff chat mid-run and watch the next merge-ready row arrive with no relay.

### 7. Later rounds review the fix, not the PR

**Problem.**
Every round reruns the label's lanes on the whole PR unless product code is unchanged (`.agents/skills/hzbook-coordinator/SKILL.md:107`); i984 took five rounds, i955 and i921 four, i956 and i983 three, and "i955 and i956 each spent a second extra round on a smaller defect the first fix introduced".
chhoumann's audit of five days of delegation found about 40% wasted, mostly full panels re-reviewing small fix diffs, with verifiers that ran the real artifact after each fix returning the most per dollar (`/tmp/agent-research/chhoumann_t3-pstack/repo/CHANGES.md:199-203`).

**Change.**
For round n greater than 1, `brief.mjs checker` fills the existing `{FIX_SCOPE}` slot with `git diff <previous head> <head>` and the findings being closed; review lanes judge the fix diff and each finding's closure, and the live lane re-drives the verify items the findings touched plus the unit's named flow once.
A finding outside the fix diff in a later round is a follow-up unless the fix introduced it.
BODY and copy findings never open a round alone; they batch into the last one.

**Deletes and adds.**
About 20 lines in `brief.mjs` and six in the lane templates.

**Risk and proof.**
A regression elsewhere in the PR missed in round 2; the named-flow pass and the local gate cover it.
Proof: rounds and checker minutes per standard unit in the next pack against the 2026-10-14 mean of about three rounds.

### 8. An enforcement table for the builder and checker rules

**Problem.**
Thirteen prose rules, 873 words, go into every builder brief; rule 11 was broken twice before it got a hook, and the table pairing each rule with its enforcer has sat in the housekeeping list since 2026-10-13.
The lessons skill has the ladder but no table to drive lens 3.

**Change.**
`orchestrate/coordinator/enforcement.md`: one row per builder and checker rule with its enforcer (hook, script refusal, merge gate line, test, or "prose"); a test fails when a rule has no row; the lessons skill reads the table, and a broken rule marked prose must climb.
Candidates visible today: rule 5 becomes `state.mjs verdict` refusing a verdict file without a `HEAD:` line equal to the round's head and evidence under each in-scope item (pstack's plan linter idea, `U/skills/poteto-mode/scripts/check-plan.mjs`); rule 12 becomes a PreToolUse hook on `AskUserQuestion` beside the shared-state guard; rule 10's `created.tsv` worktree rows become a read of T3's worktree list in `cleanup.sh`.
A rule whose enforcer makes it moot leaves the brief.

**Where it comes from.**
pstack `correct`: "keep a table ... that pairs each rule with what enforces it ... If the rule was already there and nothing enforces it, that's a repeat" (`U/skills/correct/SKILL.md`).

**Deletes and adds.**
Three to five rules leave the brief; a 30-line table, a 20-line test, two hooks.

**Proof.**
The pack's rules-against-reality lens reports fewer prose-only breaks per run.

### 9. Two T3 misreads in the chief of staff

`statuses: ["waiting"]` is read as "threads stopped on a question" (`.agents/skills/hzbook-cos/SKILL.md:60`), but in T3 `waiting` is post-turn drain while background work holds (`T3/apps/server/src/orchestration-v2/Orchestrator.ts:545-549`), so every coordinator with a Monitor shows as waiting on Bryce and a real question, which is a `pendingRequestCount` on a running run, is missed.
The fix is to drop the T3 status read: the inbox's `gate` and `plan` rows are the questions, and proposal 1 removes the Monitors anyway.
The skill also says a retry with the same `clientRequestId` starts no second checker; that holds only within one provider session (checked by the orchestrator), so after an idle release the coordinator checks `created.tsv` or `t3_thread_list` children before retrying.
Two sentences change.

### 10. Ship `agents/openai.yaml` from the build

The four generated skills set `disable-model-invocation: true` and ship no `agents/openai.yaml` with `allow_implicit_invocation: false`, which Codex reads instead (checked by the orchestrator; `/tmp/agent-research/mariusflorescu_pstack-t3/repo/skills/poteto-mode/agents/openai.yaml`).
The GPT checker runs on Codex with those skills linked into `~/.agents/skills`, so it may load the coordinator skill mid-review.
Four lines in `build.mjs` and a doctor check that the two flags agree.

### 11. Settle the two open hypotheses with one evening of probes

Whether the chief of staff's tick buzzes Bryce's phone: a completed turn that holds no background work pushes (`T3/packages/shared/src/agentAwareness.ts:100-108`), and the chief of staff holds nothing, so the source says yes every 30 minutes while anything is live.
If the phone confirms it, proposal 6 makes doorbells the main wake and the interval hourly, and the chief of staff's quiet drains fall to one an hour.
Whether usage-limit auto-resume fires through claude-proxy: T3 needs a `resetAt` the proxy may not send (`ClaudeAdapterV2.ts:2792-2816`); check `statev2.sqlite` for 2026-10-14's limit failures, and if none carries a reset time, the hourly tick stays the recovery and the plan says so.

### 12. A strategic track through the findings buffer

The target design's second track ("end every run with at most one environment-improvement ticket", `docs/plans/hzbook-agent-workflow.md`, The coordinator) was never built, and Bryce has since ruled "we don't really wanna keep spinning up new tickets".
poteto's answer is the buffer: append, read every few days, fix the shared cause.
Change: `state.mjs finish` prompts for one `env` finding per run (what slowed it: a flake, a shared resource, a missing stand-in, a BLOCKED lane) appended to `findings.md`, and the chief of staff's seven-day findings review groups them; a BLOCKED live verdict also proposes a `pstack:maintain-verification-skill` child task, since `verify-hzbook` is the infrastructure every verdict rests on and it has had one maintain pass.
Ten lines; the Snapcaster store's findings (slots, volumes, inodes, inotify) show the shape of what this catches.

## Radical alternative

If this workflow were rebuilt on T3 today with the run results in hand, it would be one delegation tree per run, one chat per project, and the same scripts, at about half the size.

**Shape.**
The chief of staff stays a disposable top-level chat per project, because a chat is disposable but a run is not; its wakes are Bryce, child completions for direct tasks, and its tick, which doorbells fire.
A coordinator is a top-level thread per run, as now, launched by the chief of staff, because it outlives any chat.
Builders and checkers are its `delegate_task` children in worktrees; every completion wakes it; a later round is a `t3_thread_send` to the child.
There is no watcher, no Monitor, no heartbeat and no liveness judge: the coordinator learns of CI from its builders' results, of merges from its own `gh pr merge`, and of outside merges from `state.mjs reconcile` at an hourly tick that exists only while children are live.

**Pieces and sizes.**
Scripts, about 2,500 lines from 3,960: `state.mjs` (450), `merge-ready.mjs` (220), `main.mjs` (300), `approve.mjs` and `inbox.mjs` (230), `brief.mjs` for the coordinator and the chief of staff (350), `evidence.mjs` (60), `models.mjs`, `profile*.mjs` and `build.mjs` with the budget and the T3 tool-name check (480), `lessons.mjs` and `replay.sh` (450), `cleanup.sh` (100, since T3 owns child worktrees).
Gone: `watch-run.sh`, `liveness.mjs`, `threads.tsv` and the `launched`, `finished` and `live` commands of `store.mjs` (T3 lists children with `parentThreadId`), `cos.id`.
Skills, about 7,000 words from 13,500: coordinator 2,500, chief of staff 1,800, lessons 1,200, builder brief and rules 900, checker brief and lanes 600, with Red main, Away, Finish and Triage as trigger-loaded references.
Store: `rulings.md` under 100 lines of policy, `rulings-archive.md`, `findings.md`, `priorities.md`, `sessions.md`, `inbox.tsv`, `approvals.tsv` per run, the run tables, under a local git.
Gates unchanged: lanes per label with the GPT seat, the local gate, patch id across rebases, folder overlap, approval rows, the main lock, and self-merge for small tickets behind the same gate.

**What it buys.**
About 60 fewer coordinator turns per long run, no builder ever lost, no relay of a thread id, one alert path to Bryce, and a system whose every rule either sits in a script that refuses or in a skill small enough that an agent follows it.

## Keep

- The refusing store and the keyed inbox: pstack's `orch` store is advisory and four times the size (`U/skills/poteto-mode/scripts/orch/store.ts`), firstmate's bookkeeping is 125,000 lines of bash, and no port has either.
- The merge gate: lanes at PASS, patch id across rebases, folder overlap against the tested base, the local gate, a required-check read of the newest run, and approval rows naming PR and head; nothing in any framework merges this carefully, and the T3 team itself has no merge queue.
- The cross-run main lock and the red-main rules in `main.mjs`; pstack has none because its owners merge, firstmate has a single-PR guard.
- Checkers as isolated child tasks in worktrees with a native GPT seat, and verdicts keyed to a head; pstack's swarm is in-process, and the ports could not run a GPT seat natively.
- Models and effort pinned per phase in `models.json` and verification policy pinned per run; pstack and marius let the agent choose at spawn time.
- `schedule_task` ticks that outlive the session; pstack's `/loop` dies with the chat.
- Away mode as a file the scripts read at the point of use (PR #71), which firstmate does with a daemon and pstack with a session override.
- The lessons pass with real-data replay, fixed lenses and the enforcement ladder; pstack's reflect has no replay and firstmate has no lessons loop at all.
- Draft PRs until code-ready and the CI-cost discipline; pstack opens PRs ready and would double the bill.
- A disposable chief of staff that cold-starts from a 3,000-token brief; pstack's recall fans out over transcripts at every start.
- The GPT review lane as the second family: 21 in-scope findings in 49 verdicts and all six solo findings on 2026-10-14 real.

## Rejected

- A GitHub webhook task into the chief of staff or coordinator: with builders as children the coordinator merges itself and reconcile catches outside merges, and each delivery is a model turn where the current watcher costs none.
- Coordinator-owned `watch_pull_request`: silent on merge, blind to Bryce's own comments, capped at ten comment wakes (`T3/apps/server/src/orchestration-v2/pullRequestWatch.ts:13,89`), and unneeded after proposal 1.
- Porting pstack's `orch` store or `watch-pr`: they converged with `state.mjs` and `merge-ready.mjs`, which are a quarter the size.
- The poteto-mode router and its 23 playbooks: a general router adds tokens to every tick for one specialized workflow.
- firstmate's watcher, busy-state and wake-queue machinery: the machinery Bryce left on 2026-10-05.
- A fresh builder per fix round (pmwoz, pstack): run 7 saved 1h20 by reuse, and a finished child accepts a follow-up task.
- Opening PRs ready instead of draft: decision 4 and the CI bill.
- A `hold.md` twin of `away.md`: `task_cancel` cascades over a child tree and `main.mjs` already refuses on `away.md`; add it only when a stop is ever needed.
- chhoumann's bot-agnostic settle window: HzBook has no review bot since Greptile was removed, Snapcaster names CodeRabbit in its profile, and no run shows a bot posting after merge-ready.
- Blind evals for prose changes to briefs: worth it only after the budget cut lands; the real-data replay is the proof we have now.
- A third model family (Grok) in panels: the Codex seat is the measured diversity and the extra seat is cost.
- One standing, never-disposable chief of staff thread: decision 3's cache and brief economics hold, and the tick doorbell removes the reason to want it.
- Merging the chief of staff and the coordinator into one agent per area (poteto's shape): runs outlive chats and Bryce wants one chat; revisit if one chief of staff cannot keep up.
- Moving the store into the agent-configs repository: scripts and T3 worktrees read it by path; a local git in the store gives history without the coupling.
- Codex builders by routing table (target design stage 3): no evidence yet, and the GPT seat's value is as a reviewer.
- Memory in GitHub issues (uzair's gist): Bryce found it awkward (`docs/plans/hzbook-cos.md`, decision 2).
- Lead-judgment filtering of checker findings by the coordinator: weakens checker independence, and every solo GPT finding on 2026-10-14 was real.
- Tick coalescing: T3 queues one run per tick with no merge (`ScheduledTaskService.ts:712-727`); a T3 issue, not ours, and proposal 1 makes ticks rare.
- `t3_thread_wait`, plan mode and `AskUserQuestion`: the standing rejections stand with source-confirmed reasons (a wait blocks the turn, the mode ceiling refuses a plan-mode sender, a pending question freezes the session).
