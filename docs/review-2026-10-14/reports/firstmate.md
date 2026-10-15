# firstmate deep-dive: what Bryce's orchestrate system should learn from it

Target: kunchenguid/firstmate at commit a24f4cb (2026-10-14), read as untrusted data, nothing executed.
Path keys used below:

- `FM/` = `/tmp/agent-research/kunchenguid_firstmate/repo/` (the upstream repo under study).
- `FMB/` = `/home/bryce/git/firstmate/` (Bryce's own firstmate home, used 2026-09-14 to 2026-10-10).
- `AC/` = `/home/bryce/git/agent-configs/` (Bryce's current system).
- `STORE/` = `~/.claude/orchestrate/hzbook/` (the HzBook store).

## 0. Bottom line

firstmate is an "agent distro": one prose contract (`FM/AGENTS.md`, 433 lines, 7,243 words) plus 216 bash/node scripts (125,385 lines) and 256 bash test files (231,016 lines), run by any terminal agent that is launched inside the clone (`FM/README.md:36-40`).
Its stated philosophy is "scripts own the mechanics, agents own the judgment" with a 9,000-word ceiling on the always-loaded contract (`FM/VISION.md:32-39`).
In practice the judgment layer is small and the mechanics layer is enormous: the watcher alone is 3,356 lines (`FM/bin/fm-watch.sh`), spawn is 6,128 (`FM/bin/fm-spawn.sh`), and the architecture doc spends one paragraph per edge case (`FM/docs/architecture.md:13-111`).
Bryce ran it for four weeks, finished 207 items with it, and left because of exactly that machinery: "most of the friction in the 2026-10-05 audit came from that machinery" (`AC/docs/plans/hzbook-agent-workflow.md:76`).
His current system already took the best structural ideas (state on disk, verbatim rulings, scripts keep the books, a record-plus-doorbell inbox) (`AC/docs/plans/hzbook-agent-workflow.md:62-72`, `AC/docs/plans/hzbook-cos.md:65`).
What is still worth taking is not machinery but four disciplines our system lacks: memory that is budgeted and retires what a skill now owns, an always-loaded size ceiling with trigger-loaded detail, a crisp rule for when a review finding stops being fixable and becomes Bryce's call, and a written list of review rulings so checkers stop re-litigating them.
Our system is ahead of firstmate on learning from runs: firstmate has no retro or lessons loop at all, while our lessons passes replay real run data before a PR (`AC/orchestrate/cos/templates/lessons-brief.md:14-21`).

## 1. Architecture

### 1.1 Roles

| Role | What it is | Source |
|---|---|---|
| Captain | The one human; the default authority for every gate | `FM/AGENTS.md:7-9`, `FM/VISION.md:23` |
| First mate | The primary agent session the captain talks to; never does project work itself | `FM/AGENTS.md:21-24`, `FM/VISION.md:25` |
| Crewmate (ship) | An autonomous worker in its own worktree and terminal endpoint that delivers a change | `FM/AGENTS.md:184`, `FM/docs/architecture.md:308-311` |
| Scout | A crewmate whose deliverable is `data/<id>/report.md`, never a PR; scratch worktree | `FM/AGENTS.md:185`, `FM/bin/fm-brief.sh:20-23` |
| Secondmate | A crewmate that is itself a full firstmate home (own `FM_HOME`, backlog, lock, charter), local or over SSH; idle by default | `FM/AGENTS.md:24`, `FM/AGENTS.md:139-145`, `FM/docs/architecture.md:324-330` |
| Supervision branch / host | A second, cheaper conversation that handles routine wakes and merges only captain-relevant outcomes into main (Pi in-process; a headless engine beside Claude by default) | `FM/docs/pi-supervision-branch.md:26-45`, `FM/docs/supervision-host.md:1-30` |
| Away daemon | A bash sub-supervisor that batches escalations while the captain is away on harnesses without the host | `FM/docs/architecture.md:201-224` |

Crewmates never address the captain; everything flows through the first mate (`FM/AGENTS.md:11`, `FM/AGENTS.md:39-41`).
`FM/GROK_BOT.md:1-31` is a separate persona for a chat-bot deployment where crewmates are persistent role bots with charters, and the first mate "update[s] their description to refine their behavior" when they err (`FM/GROK_BOT.md:21`).

### 1.2 Shape and install

Install is "clone the repo, run your agent in it" (`FM/VISION.md:73`, `FM/README.md:83-127`); `CLAUDE.md` is a two-line `@AGENTS.md` pointer and `.claude/skills` symlinks to `.agents/skills` (`FM/CONTRIBUTING.md:59`).
Private state lives in gitignored `data/`, `state/`, `config/`, `projects/` under `FM_HOME` (`FM/AGENTS.md:58-68`, `FM/.gitignore`).
Harness hooks are tracked per vendor: Claude gets SessionStart, three PreToolUse guards, UserPromptSubmit and a Stop hook with `asyncRewake` (`FM/.claude/settings.json:1-70`, the rewake at line 59); Pi and omp get TypeScript extensions (`FM/.pi/extensions/`, `FM/.omp/extensions/`), Grok, Cursor and Codex get JSON hooks.
Thirty agent-only skills under `FM/.agents/skills/` (4,352 lines) carry `metadata.internal: true`; one public skill (`FM/skills/stow`) is installer-facing (`FM/README.md:204-212`).

### 1.3 Size of the main pieces

| Piece | Lines | Note |
|---|---|---|
| `AGENTS.md` | 433 (7,243 words) | Always loaded |
| `bin/` (216 files) | 125,385 | Bash plus a few node/python |
| `tests/` (256 `*.test.sh`) | 231,016 | About twice the code; 5,471 assertions |
| `.agents/skills/` | 4,352 | Biggest: `fmx-respond` 328, `stow` 322, `afk` 278 |
| `docs/` | 18,942 | `configuration.md` alone is 2,630 |
| Harness extensions | 12,334 | Pi/omp/OpenCode watchers and guards |
| `bin/fm-spawn.sh` | 6,128 | Launch, isolation, fail-closed validation |
| `bin/fm-teardown.sh` | 3,943 | Landed-work test, backlog close |
| `bin/fm-watch.sh` | 3,356 | Zero-token watcher |
| `bin/fm-classify-lib.sh` | 2,742 | Status verbs, decision fold |
| `bin/fm-captain-hold.sh` | 2,056 | Decisions as held tasks |
| `bin/fm-pr-merge.sh` | 1,800 | Merge guard |
| `bin/fm-brief.sh` / `bin/fm-dod-lib.sh` | 806 / 761 | Brief scaffold, definition of done |

For comparison our whole orchestrate source is 4,378 lines (`AC/orchestrate/`), and the compiled skills are 277 and 211 lines (5,892 and 3,546 words) for HzBook's coordinator and chief of staff (`AC/.agents/skills/hzbook-coordinator/SKILL.md`, `AC/.agents/skills/hzbook-cos/SKILL.md`).

### 1.4 Adapters per runtime

Two axes are abstracted.
Harness (the agent CLI): 15 verified adapters (claude, codex, opencode, pi, pi-signed, grok, kimi, cursor, omp, plus muse, gemini, rovo, agy, devin, commandcode for workers only), and dispatch on an unverified one is refused (`FM/AGENTS.md:91-95`, `FM/.agents/skills/harness-adapters/SKILL.md:24-38`).
Each harness gets one reference file (`FM/.agents/skills/harness-adapters/references/harness/*.md`) and its own supervision protocol (`FM/docs/supervision-protocols/claude.md:1-27` and siblings).
Runtime backend (where terminals live): tmux is the reference, Herdr has a CI lane, Zellij, Orca and cmux are experimental (`FM/docs/architecture.md:257-281`).
"Busy" is read from each vendor's own lifecycle events (Claude's UserPromptSubmit/Stop hooks, Pi's `agent_start`/`agent_settled`), never from rendered text, and unknown is never promoted to busy or idle (`FM/docs/architecture.md:235-255`).

### 1.5 Brief format

`bin/fm-brief.sh` scaffolds `data/<id>/brief.md`; the agent fills only two slots (`FM/bin/fm-brief.sh:1-16`):

- `## Captain's intent` holds the captain's own words plus the substance of any report or PR they point to, and nothing the first mate added (`FM/AGENTS.md:389`).
- `## Firstmate spec` holds build instructions, naming what stays out of scope (`FM/AGENTS.md:390`).
- Spawn refuses leftover placeholders and a Captain's-intent line that opens with an address (`FM/bin/fm-brief.sh:11-13`).

The generated ship brief then fixes the contract (`FM/bin/fm-brief.sh:748-806`): an isolation self-check that stops if launched in the primary checkout (757), a branch step, sparse status appends that each wake the supervisor (773-781), "same obstacle twice, append blocked and stop" (783), a shared rule never to administer the daemon or the worktree pool (`FM/bin/fm-brief.sh:637-661`), a project-memory rule that a worker may only correct `AGENTS.md`, never add to it (793-796), and the mode's Definition of done rendered from one owner (`FM/bin/fm-dod-lib.sh:411-535`).
A no-mistakes worker passes only the Captain's-intent text as the pipeline's `--intent`, so the AI reviewer judges against the captain's words rather than the orchestrator's spec (`FM/bin/fm-dod-lib.sh:366-373`).
The status protocol is a line grammar: `working`, `needs-decision`, `blocked`, `paused` (a declared external wait, optionally `until <time>`), `done`, `failed`, `resolved`, with optional `[key=...]` (`FM/bin/fm-brief.sh:113-117`, `FM/bin/fm-classify-lib.sh:1-45`).

### 1.6 Backlog

The backlog is markdown managed by an external `tasks-axi` CLI: `data/backlog.md` with `## In flight`, `## Queued`, `## Done`, keep 10 Done, archive to `data/done-archive.md` (`FM/.tasks.toml:1-6`, `FM/docs/configuration.md:341-400`).
Spawn moves the item to In flight and teardown closes it in the same locked step, and both refuse rather than report success without it (`FM/AGENTS.md:374`, `FM/docs/configuration.md:353-364`).
A decision is not a separate object: it is a backlog task held for the captain via `fm-captain-hold.sh hold <id> --reason ... [--until <date>]` (`FM/AGENTS.md:371`, `FM/.agents/skills/captain-hold-lifecycle/SKILL.md:13-36`).

### 1.7 The no-mistakes gate

no-mistakes is a separate kunchenguid tool: a local git remote proxy whose push runs an AI review, test, lint and document pipeline in an isolated worktree, then pushes and opens the PR (`FM/CONTRIBUTING.md:9-11`).
Per project the captain picks `no-mistakes`, `direct-PR` or `local-only`, with `+yolo` as the only standing merge relaxation (`FM/AGENTS.md:192-200`, `FM/AGENTS.md:239-241`).
When the pipeline is selected it alone owns review, fixes, tests, docs, push, PR and CI, and the first mate must not add a manual reviewer on top (`FM/AGENTS.md:228-232`).
Its `ask-user` findings go to the first mate, never answered by the worker, and `--yes` is banned fleet-wide (`FM/bin/fm-dod-lib.sh:389-395`).
Upstream PRs must carry an attestation bound to the current head SHA, checked by a required GitHub job (`FM/CONTRIBUTING.md:12-15`, `FM/.github/workflows/no-mistakes-required.yml`); the check is structural, not cryptographic (it proves the body claims the steps ran at that head, not that they did).
When firstmate validates itself, `disable_project_settings: true` stops gate agents from loading the fleet-captain identity (`FM/.no-mistakes.yaml:10`, `FM/docs/architecture.md:300-306`).

## 2. Orchestration

### 2.1 Intake and dispatch

Every request is resolved to one project, then classified ship or scout; a scout is only for a requested knowledge deliverable or uncertainty that could change what to build (`FM/AGENTS.md:170-190`).
"Evidence is never authorization": a diagnosis or recommendation authorizes nothing (`FM/VISION.md:28`, `FM/AGENTS.md:189`).
"Never both present a likely-enough solution and launch a parallel design exercise that is not expected to change it" (`FM/AGENTS.md:188`).
"Do not build wrappers, control planes, policy layers, custom verifiers, or automation unless the direct path exposes a concrete blocker" (`FM/AGENTS.md:178-179`).
Spawn goes only through `bin/fm-spawn.sh`, which refuses brief and flag disagreement on mode, forge, branch and base (`FM/AGENTS.md:210-212`, `FM/docs/architecture.md:366-372`).

### 2.2 Isolation

Each task gets a pooled worktree from `treehouse` (or Orca's own), and both the spawn assertion and the brief's first step enforce it (`FM/docs/architecture.md:283-298`, `FM/AGENTS.md:301`).
For firstmate's own repo the tangle detector treats a named non-default branch in the primary checkout as a fault (`FM/docs/architecture.md:289-297`).
A PreToolUse guard denies the primary any delegation-shaped tool (Claude's Task/subagent) because an untracked subagent writes no task record, so nothing supervises it; the doc cites a 2026-07-22 incident where four subagent workers vanished on restart (`FM/docs/subagent-guard.md:7-21`).
A second guard denies a persistent `cd projects/<clone>` in the primary shell after a backlog write once landed inside a clone (`FM/docs/cd-guard.md:13-16`).

### 2.3 Monitoring

A bash watcher sleeps on the fleet and classifies wakes with zero tokens; only actionable ones are written to a durable `state/.wake-queue` and wake the agent (`FM/docs/architecture.md:13`, `FM/docs/architecture.md:68`, `FM/README.md:51`).
On Claude the Stop hook re-arms the watcher with `asyncRewake` and turns an actionable close into an exit-2 rewake, so the model never spends tokens arming it (`FM/docs/supervision-protocols/claude.md:6-10`).
Wake kinds are `signal:` (status line appended), `stale:` (pane unchanged), `check:` (registered poll result such as a PR merge), `heartbeat:` (`FM/AGENTS.md:280-288`).
Each wake turn drains the queue first and acknowledges with a generation-bound `--ack-through` only after handling, so a crash replays rather than loses (`FM/AGENTS.md:270-276`).
A status line is "a wake event, not current-state truth"; `bin/fm-crew-state.sh` derives current state from the pipeline run and semantic busy state (`FM/AGENTS.md:67`, `FM/docs/architecture.md:126-139`).
Absorb only on positive evidence: a no-verb wake is silenced only when the worker provably runs a pipeline step or is provably busy (`FM/docs/architecture.md:86-89`).
An open `needs-decision` stays visible on every drain until a `resolved` line with its key lands, and the answerer writes that line at answer time (`FM/docs/architecture.md:113-120`).
A dead endpoint is reported once, not escalated forever: the doc cites two finished lanes that hit 226 and 203 consecutive escalations (`FM/docs/architecture.md:56-61`).
The rule "No turn ends blind while work is under way" is backed by a turn-end Stop guard that blocks when work is in flight and no supervision cycle is provably alive (`FM/AGENTS.md:268`, `FM/AGENTS.md:302`, `FM/docs/turnend-guard.md`).

### 2.4 Restart and recovery

"A restart must be a non-event because durable state and live backend inventory, not conversation memory, are authoritative" (`FM/AGENTS.md:130`, `FM/VISION.md:41-46`).
`bin/fm-session-start.sh` runs once and prints one digest (lock, bootstrap, wake drain, supervision protocol, memory files, backlog, task meta, status tails) with a do-not-re-read contract (`FM/bin/fm-session-start.sh:1-60`, `FM/AGENTS.md:78-81`).
A stuck worker is escalated in order: peek and check its steering inbox, answer a question its brief already answers, interrupt and redirect, relaunch in the same worktree with a progress note, then report failed after a second failed relaunch (`FM/.agents/skills/stuck-crewmate-recovery/SKILL.md:72-83`).
"A low context reading is not wedging; modern harnesses auto-compact and keep going" (same file, line 81).
A worker claiming the pipeline daemon died is checked against `daemon status` before anyone believes it, because a timed-out drive call is not daemon death (same file, lines 51-68).

### 2.5 How results come back

Status appends are sparse and supervisor-actionable only; the worker's pane carries progress (`FM/bin/fm-brief.sh:773-781`, `FM/AGENTS.md:400`).
A ship's `done:` is accepted only when its named head is reachable outside the worker's disposable copy (`FM/bin/fm-dod-lib.sh:25-46`).
A scout's report must stand alone (what was done, evidence with file:line, recommendation) before its worktree can be discarded (`FM/.agents/skills/scout-completion/SKILL.md:11-16`).
Steers to a worker are a durable file record plus a constant one-line doorbell typed into its terminal; the worker acknowledges by moving the file to `handled/`, and the watcher re-rings unacknowledged records (`FM/bin/fm-task-inbox-lib.sh:1-40`, `FM/AGENTS.md:216`).
Text for the worker and lifecycle commands are separate planes: `fm-send` for text, `fm-control.sh interrupt|exit|relaunch` for process control, because "routing-marked lifecycle text becomes chat the worker reasons about instead of executing" (`FM/AGENTS.md:219-220`, `FM/docs/architecture.md:230-233`).

### 2.6 How the human is looped in

Reach the captain immediately only for review-ready work with its URL, finished findings, escalated gate findings, real blockers, anything destructive, and credentials (`FM/AGENTS.md:347-354`).
Talk in outcomes; a long table translates internal words (worktree to "local copy", teardown to "cleanup", wake to "notification") and forbids relaying worker output verbatim (`FM/AGENTS.md:316-341`).
The final message of a turn must stand alone with every outcome, decision and full PR URL, because "the captain may see only the final message" (`FM/AGENTS.md:318-321`, `FM/AGENTS.md:363`).
A true no-op gets exactly `Captain, shipshape.` (`FM/AGENTS.md:358`).
`/ahoy` recaps since the last real captain message, then walks open decisions one at a time in the first mate's impact order with a recommendation each (`FM/.agents/skills/ahoy/SKILL.md:34-51`).
`/bearings` renders four fixed sections from one deterministic snapshot command: Captain's Call, Recently Landed, Underway, Charted Next (`FM/.agents/skills/bearings/SKILL.md:39-53`, `FM/.agents/skills/bearings/SKILL.md:145-172`).
Holds are bucketed from structured fields only: `blocked`, `dated` (future `--until`), `aged` (undated past a threshold), else `live`, and only `live` shows in Captain's Call (`FM/.agents/skills/bearings/SKILL.md:47-53`).
"When the captain says 'later', that is an answer too: re-hold with `--until <date>`" (`FM/.agents/skills/captain-hold-lifecycle/SKILL.md:36`).
Captain answers are recorded verbatim with `fm-captain-hold.sh answer`, and a `RECORD DIVERGENCE` line surfaces when the status decision and the backlog hold disagree (`FM/.agents/skills/captain-hold-lifecycle/SKILL.md:32-56`).
`/afk` writes the captain's away words verbatim and no parser reads them; only mechanical limits are scripted (green at live head, synchronous merges, a worker spend cap) (`FM/docs/architecture.md:191-194`, `FM/bin/fm-afk-contract.sh:1-30`).

### 2.7 PR, CI and merge

Merge authority is separate from delivery rigor: with `yolo` off the captain approves every merge, and no setting allows a red merge without an explicit named-check waiver (`FM/AGENTS.md:239-243`).
`bin/fm-pr-merge.sh` reads everything live at merge time: open, not draft, mergeable, every check green at the exact head, every required check (from rulesets, with producer-app binding) reported (`FM/bin/fm-pr-merge.sh:1-45`).
Teardown refuses unlanded or uncommitted work and `--force` needs explicit discard authority (`FM/AGENTS.md:35-38`, `FM/bin/fm-teardown.sh:1-40`).
Merged-PR wakes refresh local clones only when the clone is clean and on its default branch (`FM/docs/architecture.md:486-494`).

### 2.8 Model routing across vendors

`config/crew-dispatch.json` holds natural-language `when` rules mapping to harness/model/effort profiles or arrays; the agent picks a rule by judgment and scripts only validate shape (`FM/docs/configuration.md:1170-1200`, `FM/docs/architecture.md:313-322`).
Arrays are resolved by `quota-array-dispatch`, which reads one `quota-axi` snapshot and ranks candidates by its `spendPriority` after eligibility, reasoning-class and runway gates (`FM/.agents/skills/quota-array-dispatch/SKILL.md:14-60`, `FM/AGENTS.md:96-111`).
"Never downgrade the intelligence doing the work without the captain's standing, explicit permission" (`FM/VISION.md:67`, `FM/AGENTS.md:105`).
Effort fallback: low for well-understood work, xhigh for ambiguous investigation, never max without captain preference (`FM/AGENTS.md:110`).
Bryce's own file routed by complexity label (small to Opus medium, standard to Codex Sol or Opus high, deep to Opus 1M xhigh, scouts to Grok then Codex then Opus) (`FMB/config/crew-dispatch.json`).

### 2.9 Concurrency and resource limits

There is deliberately no concurrency cap: file overlap is "a risk signal rather than an automatic reason to wait", and only a true semantic dependency serializes (`FM/AGENTS.md:202-204`).
An optional `config/project-capacity` caps workers per project; a spawn beyond it exits 75, creates nothing and leaves the item queued (`FM/docs/configuration.md:1147-1168`).
Bryce hit the uncapped default hard: "Nine concurrent Snapcaster validation runs pushed load to 90-110" (`FMB/data/memory-archive.md:114`).

## 3. Memory

What persists, and where:

| Store | Content | Lifetime rule | Source |
|---|---|---|---|
| `data/captain.md` | Captain preferences and authority boundaries | Default `pinned`, inspect-then-update | `FM/docs/configuration.md:662-668` |
| `data/captain-shared.md` | Preferences shared to secondmates | Primary-owned, read-only in mates | same |
| `data/learnings.md` | Operational facts and gotchas | Default `aging`, must re-prove itself | `FM/docs/configuration.md:670-675` |
| `data/memory-archive.md` | Cold tier, never loaded or counted | Append-only, recover with grep | `FM/.agents/skills/stow/SKILL.md:140-154` |
| `data/backlog.md`, `data/done-archive.md` | Work items, notes, holds | Keep 10 Done | `FM/.tasks.toml:1-6` |
| `data/<id>/brief.md`, `report.md` | Per task contract and findings | Kept with the task | `FM/AGENTS.md:154` |
| `state/<id>.status`, `.meta`, `.inbox/`, `.wake-queue` | Runtime events and records | Pruned at teardown | `FM/docs/configuration.md:83-97` |
| Project `AGENTS.md` | Project knowledge | Only humans add; workers only correct | `FM/AGENTS.md:155-160` |
| Declared external tiers | MCP memory stores named in a `Memory layering` section | The tier's own rule | `FM/docs/configuration.md:677-697` |

Recall: the session-start digest prints the three memory files in full every session (`FM/docs/configuration.md:664`, `FM/docs/configuration.md:672`).
Routing: every fact goes to "its most specific owner", from captain preference to learnings to task note to project `AGENTS.md` (`FM/AGENTS.md:147-161`).
Task notes are rewritten, never appended to, and must avoid temporary paths and copied state that will rot (`FM/AGENTS.md:381-384`).
Pruning is the `/stow` skill (`FM/.agents/skills/stow/SKILL.md`):

- Tiers by trailing marker: `<!--p:DATE-->` perishable (stale at 7 days, must name a checkable expiry), `<!--a:DATE-->` aging (stale at 30 days), unmarked in captain files means pinned (lines 17-59).
- "Reinforcement requires independent evidence from this session that you can name in the receipt; plausibility, importance, prior knowledge, and the entry's own text are not evidence" (line 105).
- Stale never means deleted: it moves to the cold archive with source, tier, date and reason (lines 140-154).
- A hard budget: `bin/fm-startup-memory-budget.sh report` estimates `ceil(bytes/3)` tokens over the three files against a default 7,500 (`FM/docs/configuration.md:699-720`); the pass must end at or under budget or open a concrete captain decision (`FM/.agents/skills/stow/SKILL.md:120-134`).
- Over budget, current but conditional entries are offloaded to on-demand owners such as a local, git-excluded skill, and only after that owner is live (lines 156-217).
- The pass also files any open work the session holds that was never recorded (lines 248-257), and ends with a receipt that only claims "reset-safe" when everything is captured and within budget (lines 270-285).
- A daily watcher check flags 2,048 bytes of growth in always-loaded files or 250 tokens in memory against a retained baseline (`FM/bin/fm-startup-growth-check.sh:92-93`, `FM/docs/configuration.md:722-742`).

It works in the field: Bryce's home went "over budget (10546 of 7500 estimated tokens)" on 2026-09-19 and one pass archived duplicates and consolidated report-sized learnings (`FMB/data/memory-archive.md:7`).

## 4. Self-improvement

There is no retro or lessons loop over finished runs; a repo-wide search finds "lesson" only in `stow`'s routing lines (`FM/.agents/skills/stow/SKILL.md:180`, `FM/.agents/skills/stow/SKILL.md:237`).
Learning happens through four channels instead:

- Memory curation: `/stow` captures preferences and gotchas into `data/` and decays them (section 3).
- Incident-to-code: "field incidents become regression coverage" (`FM/VISION.md:75`); 42 test files cite a PR or issue and 38 carry dated incident comments, for example `FM/tests/fm-brief.test.sh:483-509` (PR #5317) and `FM/tests/fm-dod-lib.test.sh:3` (issue 4768).
- Guards born from incidents, each doc opening with the incident it prevents (`FM/docs/subagent-guard.md:7-21`, `FM/docs/cd-guard.md:13-16`).
- Upstream contribution: a user/operator home that hits a firstmate bug diagnoses and patches locally and may draft an issue, but publishes nothing upstream without an explicit grant enforced in code (`FM/.agents/skills/firstmate-self-repo/SKILL.md:24-61`, `FM/bin/fm-role-lib.sh`); `/updatefirstmate` pulls fixes back (`FM/AGENTS.md:403-408`).

How changes to its own behavior are verified:

- Every tracked change ships through no-mistakes plus a captain merge (`FM/AGENTS.md:46-49`, `FM/CONTRIBUTING.md:89-93`).
- Rules that live in rendered scripts are tested on the rendered text: about 40 cases on the brief (`FM/tests/fm-brief.test.sh:34-1542`), for example the `--yes` ban phrasing at `FM/tests/fm-brief.test.sh:472-480`.
- Moving a rule out of `AGENTS.md` into a script is how it becomes testable; the prose itself is barely checked: the 9,000-word ceiling, skill frontmatter, trigger-index completeness, one-sentence-per-line and the em-dash ban have no check anywhere (test survey of `FM/bin/` and `FM/tests/`).
- Opt-in model evals run a skill against scenarios and diff the plan: the harness-adapters router is fed 15 scenarios on a local Ollama model and its JSON plan compared to the expected one (`FM/tests/fm-harness-adapter-instructions-live-e2e.test.sh:1-47`), and `--changed` selects that eval when the skill is edited (`FM/bin/fm-test-run.sh:1671-1674`).
- Disposable lab homes let a real primary run inside the gate without touching the live fleet (`FM/bin/fm-lab-home.sh:1-25`, `FM/bin/fm-live-lab.sh:1-40`).
- Vendor-dependent checks need two tests: a portable regression with real processes, and a live guard that fails naming the harness and version (`FM/.agents/skills/firstmate-coding-guidelines/SKILL.md:84-106`).
- Recorded real tool output is replayed in tests, with a table of what remains unproven live (`FM/tests/captures/no-mistakes-v1.70.1/README.md:3-52`).

## 5. Engineering practices: code versus prose

Enforced by code:

- Teardown refuses unlanded or dirty work, with 20+ refusal cases (`FM/tests/fm-teardown.test.sh:822-2952`).
- Merge refuses red or unreported required checks, including a check that turns red between two reads (`FM/tests/fm-pr-merge.test.sh:921-951`, `FM/tests/fm-pr-merge.test.sh:3164-3192`).
- The wake queue survives 40 concurrent appends and a TERM at any point (`FM/tests/fm-wake-queue.test.sh:21-55`).
- Gate agents cannot drive the real fleet (`FM/tests/fm-gate-refuse.test.sh:105-139`).
- "No agent co-author" is a commit-msg hook installed into worker launches (`FM/bin/fm-git-strip-ai-trailers.sh:1-30`).
- `.no-mistakes.yaml` may not set `commands.test` (`FM/tests/fm-nm-test-contract.test.sh:10-23`), after a pinned 75-162-script walk took 32.7 minutes per validation against 3.6 targeted (`FM/.agents/skills/firstmate-coding-guidelines/SKILL.md:115-119`).
- ShellCheck and actionlint are pinned to exact versions and refuse any other (`FM/bin/fm-lint.sh:117`, `FM/CONTRIBUTING.md:72-79`).
- Doc placement is machine-checked: every prose file is classified to one audience and its links resolve (`FM/docs/documentation-audiences.md:1-28`, `FM/bin/fm-doc-audience-check.sh`).
- A coverage guard proves every test file runs in exactly one CI lane (`FM/bin/fm-test-run.sh:1057-1175`).

Enforced by prose only:

- The one-owner rule: every contract stated once, every other mention a one-line pointer (`FM/.agents/skills/firstmate-coding-guidelines/SKILL.md:41-47`).
- The knowledge-placement tree: always needed goes inline, situational goes in a trigger-loaded skill, mechanics go in the script header (same file, lines 18-39).
- The inline-stub pattern: when detail moves to a skill, leave only the trigger (same file, lines 49-56).
- Size discipline, written because `AGENTS.md` "grew from 585 to 958 lines between its last two restructures" (same file, line 15).
- Tests must exercise behavior through a public interface and never assert source bytes (same file, line 132), which is why the prose has so few direct checks.
- Review rulings are written down "so that a decision already argued out on one pull request is not re-litigated on the next one" (`FM/.greptile/rules.md:1-6`).

Review is single-owner: the pipeline reviews, and a manual reviewer on top is forbidden unless the captain asks (`FM/AGENTS.md:229-232`).
Finding authority has its own skill: decide anything unambiguous toward accepted intent, escalate only a contract expansion, an unsettled product call, "repeated same-theme findings when incremental corrections are preserving a questionable abstraction rather than closing independent defects", or anything destructive (`FM/.agents/skills/ask-user-authority/SKILL.md:23-37`).
An escalation carries five parts: the original requirement, the proposed expansion, the smallest compliant alternative, the consequences either way, and a recommendation (same file, lines 41-47).
Bug work follows `diagnostic-reasoning`: separate the initiating trigger, the masking condition and the visible symptom, compare the failing path with a proven path, test the smallest counterfactual, seek disconfirming evidence, and make the reproduction the regression test (`FM/.agents/skills/diagnostic-reasoning/SKILL.md:18-53`).

## 6. Simplicity: what it leaves out, and what it does not

Deliberately left out:

- The first mate does no project work at all, "because trivial is a guess and command attention does not scale" (`FM/VISION.md:25`).
- Depth is capped: "every layer between the captain's intent and the acting agent costs fidelity and tokens" (`FM/VISION.md:38`).
- No secondmate self-directed work: "an empty queue never authorizes a survey, audit, or self-directed improvement sweep" (`FM/AGENTS.md:143-144`).
- No shared learnings file "by captain decision" (`FM/docs/configuration.md:675`).
- `/stow` never writes a tracked skill (`FM/.agents/skills/stow/SKILL.md:179-181`).
- No parser for the captain's away words (`FM/docs/architecture.md:192`).
- No prose lint, by choice (`FM/docs/documentation-audiences.md:26-28`).
- New task shapes only "when existing primitives genuinely cannot compose to cover it" (`FM/VISION.md:54`).

What it does not leave out: every failure mode it has met becomes a mechanism.
The watcher's stale path alone stacks declared waits, captain holds, parked gates, worktree-write evidence, dead-record once-markers, busy bounds and pane-churn absorb (`FM/docs/architecture.md:14-66`), and half of those are opt-in flags (`config/wedge-defer-parked-gate`, `config/turnend-churn-absorb`, `config/wait-no-turns`) (`FM/docs/configuration.md:606-647`).
`AGENTS.md` sentences run to 90+ words of nested exceptions (`FM/AGENTS.md:32`), the opposite of plain language.
State is large: per task a meta file, an append-only status log, an inbox directory, wake markers, ring state, seen-signatures and hash markers (`FM/bin/fm-task-inbox-lib.sh:24-35`, `FM/docs/architecture.md:184-185`).
The simplicity firstmate achieves is in the agent's contract, paid for with a very large script surface; Bryce's audit concluded that surface was where the friction lived (`AC/docs/plans/hzbook-agent-workflow.md:76`).

## 7. What Bryce's own firstmate run shows

Usage: 2026-09-14 to 2026-10-10, 207 finished items (96 snapcaster-backend, 65 hzbook, 21 snapcaster-client, 20 firstmate itself), 125 ships, 57 scouts, 13 captain holds (`FMB/data/done-archive.md`, `FMB/data/backlog.md`).
Workers ran Claude by default with label-based dispatch; supervisors ran Fable 1M (`FMB/config/crew-harness`, `FMB/config/secondmate-harness`).
yolo stayed off everywhere (`FMB/data/captain-shared.md:13`); he retired both secondmates on 2026-09-24 (`FMB/data/captain.md:11`).
He moved the runtime to T3 Code on 2026-09-24 and wrote a 7,409-line T3 backend for firstmate (upstream draft PR #5596, `bin/fm-t3-mcp.mjs` 1,130 lines) that upstream will not merge (`FMB/data/captain.md:14`, `FMB/data/backlog.md:4-16`).
Recorded pain:

- Wake noise: "runs of one-line 'Captain, shipshape.' replies bury the real messages ... fix the monitoring rather than answering each wake" (`FMB/data/captain.md:10`).
- Healthy T3 workers raised stuck alarms every few minutes from three causes (`FMB/data/done-archive.md:93-104`); a paused T3 worker "draws a wake every few minutes" and idle T3 workers "do not resume on their own" (`FMB/data/learnings.md:37-38`).
- Review loops: #714 took 15 rounds, which led to blast-radius labels and a six-round cap (`FMB/data/captain.md:20`, `FMB/data/captain.md:24`); "every 'also add' attached during the #712 and #714 reviews was later reversed" (`FMB/data/captain.md:22`).
- Load: nine concurrent validation runs pushed load to 90-110 (`FMB/data/memory-archive.md:114`).
- Unfixed firstmate bugs still queued at exit, such as relaunch breaking the merge poll and the pool recycling a held worktree (`FMB/data/backlog.md:19-125`).

Why he left, in his words: "firstmate contributes durability and intake ideas, not its machinery" (`AC/docs/plans/hzbook-agent-workflow.md:63`), and he kept state on disk, a rulings file, label routing, GitHub intake, scouts, holds and authority, and learnings (`AC/docs/plans/hzbook-agent-workflow.md:65-72`).
Later he borrowed "scripts for every mechanical step, so the agent judges and the scripts keep the books" (`AC/docs/plans/hzbook-pstack-takeover.md:139-145`) and the parent channel as the model for the CoS inbox (`AC/docs/plans/hzbook-cos.md:65`).
Several current rules are firstmate captain.md entries carried over: narrowest remedy, blast-radius labels, no bare ticket numbers, the round cap (`FMB/data/captain.md:20-24`).

## 8. Ideas worth stealing, ranked

### 1. Retire what a skill now owns, and put a budget on the store's always-read memory

What: firstmate's always-loaded memory has a token budget, tiers with decay, a cold archive that keeps provenance, and the rule that a fact moves to its most specific on-demand owner and then leaves always-loaded memory (`FM/.agents/skills/stow/SKILL.md:80-154`, `FM/.agents/skills/stow/SKILL.md:156-217`, `FM/docs/configuration.md:699-742`).
Why for us: `STORE/rulings.md` is 479 lines, appended verbatim and never pruned, and both skills read it at every start or before every proposal (`AC/.agents/skills/hzbook-coordinator/SKILL.md:35`, `AC/.agents/skills/hzbook-cos/SKILL.md:79`); `STORE/findings.md` is 88 lines and `STORE/sessions.md` 87.
Our lessons pass already moves rulings into skills, which is exactly firstmate's "offload to an on-demand owner", but nothing then removes the ruling from `rulings.md`, so every folded ruling is paid for twice (`AC/orchestrate/cos/templates/lessons-brief.md:14-21`).
How on T3: no new primitive.
Add a step to the lessons brief: for each ruling the PR encodes, move it to `STORE/rulings-archive.md` under a dated heading with `(folded into <file>, PR #n)`, and leave rulings that are still only Bryce's words.
Have `brief.mjs` print the estimated tokens of `rulings.md`, `findings.md` and `sessions.md` against a budget (firstmate's `ceil(bytes/3)` is good enough) and flag `Lessons pass due` when over (`AC/orchestrate/cos/bin/brief.mjs:179-184`).
Skip the decay markers at first: our rulings are Bryce's words, which firstmate itself treats as pinned (`FM/.agents/skills/stow/SKILL.md:49`).

### 2. A "same theme again" stop rule and a five-part escalation for review findings

What: escalate a finding instead of fixing it when it would expand the accepted contract, when it is an unsettled product call, or when "repeated same-theme findings ... are preserving a questionable abstraction rather than closing independent defects"; the escalation names requirement, expansion, smallest compliant alternative, consequences and recommendation (`FM/.agents/skills/ask-user-authority/SKILL.md:23-57`).
Why for us: our only stop is the round cap; every in-scope finding starts another fix round until `state.mjs` refuses (`AC/orchestrate/coordinator/skill/040-checking.md:16-18`).
Bryce's own history is the evidence: #714 spent 15 rounds discovering its rules and every "also add" was later reversed (`FMB/data/captain.md:20-22`).
How on T3: prose in the Checking section plus a cheap script hint.
When a round's in-scope finding shares lane and theme with one from an earlier round, the coordinator parks a gate (`state.mjs gate`) in the five-part form instead of starting the next fix round; the gate reaches the CoS inbox and Bryce's phone as today.
`state.mjs verdict` can print "repeat theme?" when the same file or lane recurs, leaving the judgment to the coordinator.
A finding that would add scope becomes a follow-up issue rather than a fix, which matches firstmate's "prefer routing new requirements to follow-up work" (`FM/.agents/skills/validation-supervision/SKILL.md:15`).

### 3. A word ceiling on the generated skills, with situational detail moved behind triggers

What: a stated ceiling for the always-loaded contract (`FM/VISION.md:39`), a placement tree that sends situational detail to trigger-loaded skills and mechanics to script headers, the one-owner rule and the inline-stub pattern (`FM/.agents/skills/firstmate-coding-guidelines/SKILL.md:18-64`).
Why for us: the coordinator skill is 5,892 words and the CoS 3,546, every lessons pass adds text, and `build.mjs --check` checks staleness only (`AC/orchestrate/README.md:3-5`, `AC/package.json` scripts).
firstmate's own `AGENTS.md` grew 585 to 958 lines before this discipline (`FM/.agents/skills/firstmate-coding-guidelines/SKILL.md:15`), and firstmate never enforced its ceiling in code, so enforce ours.
How on T3: make `orchestrate/build.mjs --check` (run by the doctor and CI) fail when a generated SKILL.md passes a word ceiling, say 4,000 for the coordinator.
Move the sections only some turns need (Away, Red main, Restart, Finish, Triage, Findings) into `references/<name>.md` beside the generated skill, leaving one trigger line each ("On a restart, read references/restart.md first").
Claude Code and Codex both load SKILL.md and read references by path, so this costs nothing in T3.

### 4. A review-rulings file that checkers read

What: `FM/.greptile/rules.md` records reviewer rulings "so that a decision already argued out on one pull request is not re-litigated on the next one", each with the conditions it depends on (`FM/.greptile/rules.md:1-20`).
Why for us: checkers get the issue's acceptance criteria and earlier findings, but not Bryce's standing review rulings, which live only in `STORE/rulings.md` and are read by the coordinator (`AC/orchestrate/coordinator/bin/brief.mjs:108`, `AC/orchestrate/coordinator/templates/checker-brief.md:1-25`).
So a checker can raise a finding Bryce already ruled out (an "also add", a style he accepted), which costs a round before the coordinator filters it.
How on T3: a short `config/<project>/review-rulings.md` in agent-configs (versioned, project-scoped), maintained by the lessons pass from rulings.md, and inserted by `brief.mjs checker` under "Standing rulings: do not raise these".
It also gives idea 1 a place to put review rulings once folded.

### 5. "Later" is an answer: dated deferral and an aged bucket for what waits on Bryce

What: a captain call can be re-held `--until <date>`, leaving the live list and resurfacing on its date; holds are bucketed `blocked`, `dated`, `aged`, `live` from structured fields only, and only `live` is presented as a decision (`FM/.agents/skills/captain-hold-lifecycle/SKILL.md:36`, `FM/.agents/skills/bearings/SKILL.md:47-53`).
Why for us: `inbox.mjs open` lists every merge-ready unit without approval, every gate or plan without answer and every red main without green, with no way to say "not now" (`AC/orchestrate/README.md:57`, `AC/.agents/skills/hzbook-cos/SKILL.md:110-111`).
A deferred item either nags in every brief or gets answered falsely to clear it.
How on T3: add a `deferred` inbox row (`key=<item>:deferred until=<date>`, Bryce's words as the body) that `open` honors until the date, and have `brief.mjs` show an "aged" line for anything waiting more than N days.
The existing 30-minute CoS tick already re-reads the inbox, so no new timer is needed; a one-shot `schedule_task` is optional for a precise date.

### 6. A head-bound verification status as a required GitHub check

What: upstream firstmate PRs need an attestation bound to the current head SHA naming the completed review, test and document steps, checked by a required job, so a push after review invalidates it automatically (`FM/CONTRIBUTING.md:12-15`).
Why for us: `merge-ready.mjs` is strong (lanes at PASS, required checks at head, patch-id against the verified head, approval row) but it is a script the coordinator runs; nothing on the PR itself says "verified at this head", so a merge from the GitHub UI or another tool skips it (`AC/orchestrate/coordinator/bin/merge-ready.mjs:1-12`).
How on T3: when `merge-ready.mjs` passes, post a commit status `orchestrate/verified` on the head with `gh api repos/<repo>/statuses/<sha>` and add that context to the base ruleset's required checks.
A status post starts no workflow, so it adds nothing to the CI bill Bryce tracks; a new head simply lacks the status until the coordinator re-verifies.
Keep it a status rather than an attestation in the body: firstmate's body attestation proves only that the text claims the steps ran (test survey of `FM/tests/fm-no-mistakes-required.test.sh:16-67`).

### 7. A diagnosis section for fix units

What: `diagnostic-reasoning` requires an end-user reproduction, trigger versus masking condition versus symptom, a failing-versus-proven path comparison, the smallest counterfactual, a named disconfirming check, and the reproduction as the regression test (`FM/.agents/skills/diagnostic-reasoning/SKILL.md:18-53`).
Why for us: the builder brief says only "find the root cause of any bug" with a pstack principle link (`AC/orchestrate/coordinator/templates/builder-brief.md:35`), and Bryce's global rules require E2E reproduction before any fix.
How on T3: for `fix/` units, `brief.mjs` adds a "Diagnosis" block to the builder's report with those five fields, and the checker lane quotes them back against its own reproduction; no new primitive.

### 8. The final message stands alone, and a jargon table for the CoS

What: "its final response message must stand alone with all key information from the whole turn", with full PR URLs copied from records, plus a table that rewrites internal terms before they reach the captain (`FM/AGENTS.md:316-341`, `FM/AGENTS.md:363`).
Why for us: T3 alerts Bryce's phone at the end of a turn, so the last message is what he reads (`AC/orchestrate/coordinator/skill/090-watcher.md`, the Monitor paragraph), and the CoS rule today is a general "plain English, no file paths, SHAs or model names" (`AC/.agents/skills/hzbook-cos/SKILL.md:205`).
How on T3: two lines in the CoS rules and a six-row translation table drawn from our own words (run, unit, lane, gate, round, worktree), so the CoS says "the review", "the fix", "your call" instead.

### 9. Scenario evals for routing prose, run when the prose changes

What: an opt-in test feeds a skill and a fixed set of scenarios to a model and diffs the returned plan against expected JSON; editing the skill selects the eval (`FM/tests/fm-harness-adapter-instructions-live-e2e.test.sh:1-47`, `FM/bin/fm-test-run.sh:1671-1674`).
Why for us: lessons passes change skill prose that decides inbox handling, what-next ranking and gate handling, and `replay.sh` proves the scripts on real data but not the prose's decisions (`AC/orchestrate/cos/templates/lessons-brief.md:17`).
How on T3: a handful of recorded inbox snapshots with the expected CoS action per row, run through a cheap model in `npm test` behind an opt-in variable, and required in the lessons brief when the CoS Inbox or the coordinator Checking section changes.

### 10. A live guard for every read of T3's internals

What: any check whose verdict depends on what a vendor emits needs a portable test and a live guard that fails naming the vendor and version (`FM/.agents/skills/firstmate-coding-guidelines/SKILL.md:84-106`).
Why for us: `lessons.mjs` reads T3's sqlite thread store and tells reasoning from replies by an id heuristic (`AC/orchestrate/cos/bin/lessons.mjs:9-10`, `AC/orchestrate/cos/bin/lessons.mjs:27-30`), and `models.mjs --check` already does this for the model catalog.
How on T3: add a doctor check that opens T3's DB read-only, asserts the tables and columns `lessons.mjs` uses, and names the T3 version when it fails, so a T3 update breaks loudly instead of producing an empty lessons pack.

Smaller ones worth a line each:

- Report a dead builder once per incarnation rather than every audit tick, after firstmate saw 226 and 203 consecutive escalations (`FM/docs/architecture.md:56-61`); check `AC/orchestrate/coordinator/bin/liveness.mjs` for the same repeat.
- Count recent writes in a builder's worktree as liveness when nothing has been pushed yet (`FM/docs/architecture.md:52-55`), as an extra signal in `liveness.mjs`.
- "Same obstacle twice: report blocked and stop" as a builder rule (`FM/bin/fm-brief.sh:783`).
- "Evidence is never authorization" for CoS direct tasks: a report recommending a fix does not start one (`FM/AGENTS.md:189`).
- A Stop-hook guard so the coordinator cannot end a turn with open units and a dead `watch.pid` (`FM/docs/turnend-guard.md`, `FM/.claude/settings.json:51-60`), but only after a probe shows T3's Claude sessions run project hooks.

## 9. Considered and rejected

- The bash watcher, wake classifier and busy-state layer (about 8,000 lines): this is the machinery Bryce left, and T3 thread status plus `watch-run.sh` under a Monitor covers it (`AC/docs/plans/hzbook-agent-workflow.md:76`).
- Runtime backends (tmux, Herdr, Zellij, Orca, cmux) and composer injection safety: T3 is the runtime.
- Fifteen harness adapters with per-vendor hooks: T3 abstracts the agent CLI, and our skills already run under Claude and Codex.
- The no-mistakes pipeline as the gate: replaced by pstack checker lanes on purpose (`AC/docs/plans/hzbook-pstack-takeover.md:22-24`).
- Secondmates: a CoS per project already is one, and Bryce retired his on 2026-09-24 (`FMB/data/captain.md:11`).
- Quota-ranked dispatch arrays (`quota-axi`, `spendPriority`): our static per-phase `models.json` is simpler and checked against T3's catalog.
- The steering inbox for builders: `t3_thread_send` with `mode: "queue"` is already durable, and our CoS inbox already uses record-plus-doorbell.
- Wake-queue acknowledgement and the OPEN DECISIONS fold: our `inbox.mjs peek`/`ack` and `open` already do this.
- A supervision branch on a cheaper model: our coordinator is that branch, and only four inbox kinds ring the CoS (`AC/.agents/skills/hzbook-cos/SKILL.md:108`).
- No concurrency cap: Bryce's own load incident argues for our builder cap and `load-ok.sh` (`FMB/data/memory-archive.md:114`).
- Captain's-intent-only `--intent` for the reviewer: our checkers already judge the issue's acceptance criteria, and the CoS already folds comment decisions into the issue body (`AC/.agents/skills/hzbook-cos/SKILL.md:185`).
- `/ahoy` one-decision-at-a-time flow: the numbered queue with `go` is Bryce's chosen interface.
- `/bearings` four-section digest and Lavish boards: `brief.mjs` plus `html_render` already serve this.
- Away-mode daemon and wedge alarm: `away.md` plus coordinator defaults cover it without a daemon.
- Scout promotion in place: our direct tasks are short, and a code task starts a fresh worktree from `origin/main`.
- Relay (X and Discord), voice relay, mail plane, fleet ledger, Calm mode: out of scope for two products.
- The self-repo publication boundary: Bryce owns his repos, and his global rules already forbid upstream PRs without a go-ahead.
- Pinned-version lint and test-shard balancing proofs: worth it at 231k test lines, not at ours.
- The nautical persona: Bryce asked for plain language.
