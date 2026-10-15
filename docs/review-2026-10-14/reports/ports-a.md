# Two T3 ports of pstack: pmwoz/t3-pstack and chhoumann/t3-pstack

Read-only research, 2026-10-14.
Nothing was executed from either repository.

Path prefixes used below:

- `P:` is `/tmp/agent-research/pmwoz_t3-pstack/repo/` (commit `5de5e8c`).
- `C:` is `/tmp/agent-research/chhoumann_t3-pstack/repo/` (commit `95fd0a6`).
- `U:` is `/tmp/agent-research/cursor_plugins/repo/pstack/` (upstream, commit `850d7f2`, pstack 0.15.25).
- `O:` is `/home/bryce/git/agent-configs/` (ours).
- `PA` is `P:plugins/pstack/skills/poteto-mode/references/t3-adapter.md`, pmwoz's one mapping file.
- `CP` is `C:plugins/pstack/skills/poteto-mode/SKILL.md`, chhoumann's rewritten poteto-mode.

## Bottom line

The two ports took opposite routes to the same goal.
pmwoz keeps upstream byte-for-byte except ten declared files, and puts every T3 mapping in one 133-line adapter the agent reads on demand (`PA:1-133`, `P:drift.json`).
chhoumann rewrites upstream's Cursor sentences in place with 173 regex substitutions, a 21-term denylist and 13 declared forks, and adds T3 behavior upstream lacks (`C:tools/substitutions.json`, `C:tools/forks.json`).
Neither port adds a memory or self-improvement system; both only re-point recall, reflect and show-me-your-work at T3 threads.
Neither has a merge gate, a main lock, a refusing state store, or approvals as data, so our run mechanics remain well ahead of both.
What they have that we lack is mostly at the edges: pmwoz tracks T3's tool contract mechanically, and chhoumann has measured several costly failure modes and encoded fixes for them.
Our 2026-10-13 port review (`O:docs/plans/hzbook-pstack-takeover.md:150-176`) covered pmwoz at an older version and did not cover chhoumann at all.

## 1. pmwoz/t3-pstack

### 1.1 What it is

A Claude Code and Codex plugin marketplace that ships upstream pstack for T3 Code (`P:README.md:1-27`).
Install is `claude plugin marketplace add pmwoz/t3-pstack` then `claude plugin install pstack@t3-pstack`, or the Codex equivalents (`P:README.md:14-21`).
Version 0.6.4, 49 commits from 2026-10-09 to 2026-10-14.
Size: 24,192 lines under `plugins/`, 972 lines of Bun/TypeScript tooling of which 444 are tests (`P:tools/*.ts`), plus a 6,311-line snapshot of T3's source under `P:t3/contract/`.
It is pinned to upstream `1e5c90a` (0.15.24) in `P:pins.json:2-6`, one pstack commit behind upstream HEAD (`/ketchup` pictures, #628).

Sync model, in `P:README.md:42-67` and `P:AGENTS.md:5-13`:

- `P:upstream/` is a verbatim snapshot of upstream at the pin, written only by `bun run sync`.
- `P:tools/lib.ts:56-65` is the only mechanical transform: it rewrites each skill's frontmatter `name` to its directory name, because Codex names skills by that field and upstream's poteto-mode says `Poteto Mode`.
- `P:tools/lib.ts:94-108` adds an `agents/openai.yaml` sidecar with `allow_implicit_invocation: false` beside every skill upstream marks `disable-model-invocation: true`, because Codex ignores the flag.
- Everything else is drift, and `P:drift.json` gives each drifted file a one-line reason.
- `bun run check` (`P:tools/check.ts:110-134`) rebuilds the expected tree from snapshot plus transform and fails on undeclared drift, a stale drift entry, unresolved conflict markers, broken links, a lost executable bit, mismatched manifest versions, and any backticked snake_case T3 tool name in port-authored lines that the pinned T3 contract does not define (`P:tools/check.ts:57-68`).
- `bun run sync` three-way merges new upstream with `git merge-file` and exits 2 on conflicts (`P:tools/sync.ts:31-52`, `:62-116`).
- `bun run watch` lists upstream commits and T3 contract commits since the pins, changed contract files, and T3 tools added or removed (`P:tools/watch.ts:22-65`).
- `bun run t3:pin` re-snapshots the T3 contract, auto-adding any new toolkit directory (`P:tools/t3.ts:19-49`).
- A project skill, `P:.claude/skills/maintain-t3-pstack/SKILL.md:1-42`, runs watch, sync, adapter review and contract update, one PR per concern, and lists new T3 tools under "Opportunities" without adopting them (`:33-36`).
- The README says a T3 scheduled task runs that skill daily (`P:README.md:65`); the "Sync upstream pstack" and "Update T3 contract to <sha>" commits in `git log` are its output.

### 1.2 Delta from upstream

`diff -rq P:upstream/pstack P:plugins/pstack` shows five changed upstream files plus additions.

- `skills/poteto-mode/SKILL.md`: name fix and one inserted line, "Under T3 Code, read `references/t3-adapter.md` before you start another skill or a subagent, and before any step that names a Cursor feature."
- `skills/setup-pstack/SKILL.md`: detects models with `orchestrator_capabilities` instead of Cursor slugs, writes `~/.agents/pstack-models.md` instead of an `.mdc` rule, uses descriptors `<providerInstanceId>:<model>@<effort>`, maps upstream's Grok defaults to `codex:gpt-6.1-sol` when no Grok instance can run child tasks, and appends a pointer line to Codex's `AGENTS.md` because Codex runs plugin hooks only after trust (`P:plugins/pstack/skills/setup-pstack/SKILL.md:14`, `:18`, `:43-61`, `:65`).
- `skills/poteto-help/SKILL.md`: T3 install steps, the new sheet path, no Custom Mode advice, and a note that `/make-bot-ui` has nothing to wake under T3 (`:11`, `:37-39`, `:53`).
- `skills/poteto-mode/scripts/worktree-audit.sh`: reads Claude and Codex JSONL transcripts from the last 30 days instead of Cursor's `agent-transcripts`.
- `skills/make-bot-ui/SKILL.md`: name fix only.
- Added: `PA`, the session-start hook (`P:plugins/pstack/hooks/session-start:1-25`), Claude and Codex manifests and hook registrations, 61 Codex sidecars, and the cursor-team-kit skills `deslop`, `control-cli`, `control-ui`.

No playbook, swarm, arena or interrogate text changed.
Every behavioral difference lives in `PA`.

### 1.3 How it maps pstack onto T3

| pstack construct | pmwoz mapping | Where |
|---|---|---|
| `Task`, parallel spawn | N `delegate_task` calls, `mode: "async"`, self-contained brief | `PA:32` |
| `subagent_type: poteto-agent` | brief starts "Read `<pstack-root>/agents/<file>.md` in full and act as it" | `PA:33` |
| `readonly: true` | sentence in the brief, plus a frozen-SHA worktree | `PA:35`, `PA:68` |
| Background wait | async is default, completion wakes the parent, end the turn, never poll | `PA:36` |
| Follow-up rounds | fresh `delegate_task` with consolidated brief and new `clientRequestId`; `t3_thread_send` to the child only for state living there | `PA:37` |
| Cancel | `task_cancel`, which also stops nested tasks and their PR watches | `PA:38` |
| `runtimeMode` | always omit, since narrower modes make the user approve each child tool call | `PA:28` |
| Cloud agents | `isolation: "worktree"` for writing lanes; a parent-made `git worktree add` for lanes on another ref | `PA:63-66` |
| Evidence | `${PSTACK_STORE:-$HOME/.pstack/store}/<repo>/<run>/`, never inside a worktree | `PA:69`, `PA:101` |
| Top-level threads | `t3_thread_launch` only on explicit user request; it does not wake the parent | `PA:72` |
| `/loop` on a PR | root arms `watch_pull_request`, ends the turn, takes the verdict from `watch-pr --status-only` on each wake | `PA:82` |
| `/loop` on a cadence | `schedule_task` interval bound to the root thread, `delete_scheduled_task` at the end | `PA:83` |
| Events a PR watch cannot see | root-bound `schedule_task` with an exit condition | `PA:85` |
| Transcripts | `t3_thread_read` with `view: "activity"`, `t3_thread_search`; pass thread IDs to children, never JSONL paths | `PA:91-94` |
| `AskQuestion` | `AskUserQuestion` on Claude; a delegated child never asks and returns `BLOCKED` | `PA:106-107` |
| Visuals | `html_preview` then `html_render` from the root, images by absolute path | `PA:108` |
| Automations | webhook or fixed-time `schedule_task`, secrets through `request_secret` | `PA:115` |

Model selection (`PA:44-59`): read the role's line in `~/.agents/pstack-models.md`, resolve the descriptor against `orchestrator_capabilities`, and fall back to the closest same-provider model with a note in the reply.
Two practical details we have not written down: on Claude the `orchestrator_capabilities` result overflows the tool limit and must be queried from its saved file with `jq` (`PA:55`), and a provider turned off for the project still appears in the catalog while `delegate_task` refuses it as "disabled for project" (`PA:54`).
Cross-provider panels mix Claude and Codex; Grok is used only when the catalog has a `grok` instance that can run child tasks (`PA:57`).

Skill invocation: pmwoz keeps upstream's `disable-model-invocation: true` and has pstack skills start each other by reading `SKILL.md` by path, because Claude's Skill tool refuses flagged skills (`PA:15-22`, `P:README.md:52`).
The README reports Claude loading `how` by path in 3 of 3 test runs (`P:README.md:52`).

Other T3 facts it encodes: never call `t3_worktree_handoff`, which detaches the provider session for up to nine minutes (`PA:70`, commit `9195a24`); never end a turn that waits only on a background shell command, since settling the thread kills it (`PA:86`); macOS zsh traps such as an unquoted `echo =====` aborting the rest of a chained line (`PA:123-129`).

### 1.4 Memory and self-improvement

No new mechanism.
recall, reflect and show-me-your-work run unchanged, re-pointed through `PA:89-94` at `t3_thread_search`, `t3_thread_list` and `t3_thread_read`.
The port's own learning loop is the adapter itself: "If a mapping here is wrong or missing, say so in the reply and fix this file in its own PR to the t3-pstack repository" (`PA:131-133`).
Its adapter fixes cite audits: "An audit of 23 /issue runs in three projects found these failures" (commit `d788ba9`), and "Two unattended /issue runs exposed four adapter gaps" (commit `c39d73e`).

### 1.5 Clever, simple, or wrong

Clever and simple:

- The whole port is one adapter plus a gate, so an upstream sync rarely conflicts (`P:README.md:67`: "Prefer a change to the adapter over a change to an upstream file").
- The T3 tool-name lint checks only lines the port wrote, so upstream's Cursor names do not trip it (`P:tools/check.ts:56-68`).
- `watch` diffs T3's tool set between pins and reports `toolsAdded` and `toolsRemoved` (`P:tools/watch.ts:46-60`); that is how the port learned `delegate_task` gained `isolation: "worktree"` and rewrote `PA:63-65` on 2026-10-14.
- Read-only review lanes read a detached worktree at a frozen SHA, because the root's own tree keeps moving (`PA:68`).

Wrong or weak:

- `PA:82` says the root "calls `watch_pull_request` and ends the turn. T3 wakes it on checks, reviews, and conflicts."
  Our builders measured the opposite on draft PRs: it "fires 'checks passed' on a draft run's skipped required check, then not again when the suites finish" (`O:orchestrate/coordinator/builder-rules.md:13`), and it woke none of twelve code-ready rounds (`O:docs/plans/hzbook-pstack-takeover.md:74-76`).
  pmwoz opens PRs ready, never draft (`PA:79`), which may avoid the trap, but it has no measurement either way.
- `PA:58` defines "a model family" as the provider instance.
  Two instances of the same model (our sheet runs Claude through `claudeAgent_claude_proxy`, `O:config/hzbook/models.json`) would then count as two families and fake panel diversity.
  chhoumann gets this right (section 2.3).
- The adapter is advisory: an agent that never opens it dispatches nothing.
  chhoumann observed exactly that failure, "A live bug-fix thread ran poteto-mode end to end with zero `delegate_task` calls" (`C:CHANGES.md:255`), and pmwoz has no ledger or check against it.
- `PA:80` makes a PR owner "a role, not a long-lived agent" with a fresh `delegate_task` per round; that fits T3's rule that only the root may watch a PR, but our run 7 found reusing the builder for description fixes saved 1h20 (`O:docs/plans/hzbook-pstack-takeover.md:172`).

## 2. chhoumann/t3-pstack

### 2.1 What it is

"Lauren Tan's pstack, with its Cursor mechanics rewritten in place for T3" so one panel can run Claude, GPT and Grok reviewers (`C:README.md:1-7`).
Install is `npx -y github:chhoumann/t3-pstack install`, which installs into every Claude Code and Codex home T3 can run, including each provider instance in T3's settings, and `doctor` reports on all of them (`C:README.md:13-21`).
Version 2.0.0-rc.4, 186 commits since 2026-10-03, synced to upstream `6ce45c5`, which is current for pstack (`C:tools/upstream.json:5-6`).
Size: 22,887 plugin lines, 3,817 tooling lines, 5,831 test lines, and a 1,015-line `C:CHANGES.md` that records measured findings per release.
Lineage: it began as a fork of Michael Denyer's pstack-claude (the port we pin), then switched its base to Lauren's tree in 2.0 (`C:CHANGES.md:63-65`).

Sync model, in `C:CONTRIBUTING.md:7-38` and `C:CONTEXT.md`:

- `C:tools/substitutions.json` holds 173 rules, each a literal or regex pattern, an optional file filter, a replacement and a rationale; most T3 behavior the port adds is an "anchored insert" that keeps an upstream sentence and appends T3 text (`C:CONTRIBUTING.md:11`).
- The denylist of 21 Cursor terms (`.mdc`, `` `Task` ``, `subagent_type`, `/loop`, cloud agents, Cursor model slugs and others) fails any sync that leaves one in a derived file (`C:tools/sync.mjs:190-215`).
- A rule that matches nothing fails the sync, because it means upstream reworded the anchor and the T3 text would vanish silently (`C:tools/sync.mjs:501-516`, `C:CONTRIBUTING.md:33`).
- `C:tools/forks.json` declares 13 files kept in the port's own form, each with `kind`, `why`, `since` and `upstream` status.
- `C:tools/generate.mjs` stamps role defaults from `C:plugins/pstack/models.json` into each skill's Models section and fails CI on stale output (`C:CONTRIBUTING.md:50-52`).
- `C:tools/frozen-hooks.json` pins both hooks files, because Codex trusts a hook by a hash of its entry and any edit silently stops routing in every Codex home (`C:CONTRIBUTING.md:84`).

### 2.2 Delta from upstream

`diff -rq U: C:plugins/pstack` shows 53 changed upstream files, 19 added paths, and excluded `make-bot-ui`, `docs/`, `automations/` and the Agent Plugins root manifest (the last because Codex then truncates each SKILL.md to 8,000 bytes, `C:CONTRIBUTING.md:83`).
Most changes are mechanical rewrites of Cursor mechanics, as in `swarm` (`C:plugins/pstack/skills/swarm/SKILL.md:30`) and `interrogate`.
The substantive additions, grouped:

Dispatch discipline (all in `CP`):

- Every subagent is a `delegate_task` from the playbook chat, with a stable `clientRequestId`, the `taskId` kept, and no polling (`CP:104`).
- A writing child gets its own `git worktree add` from `HEAD`, and the parent records its own `git status --porcelain` before dispatch and checks it is unchanged after (`CP:106`).
- A delegated step must run on its role's sheet entry, not in the parent's own tool calls, unless a reason is stated (`CP:106`).
- Every playbook reply ends with a dispatch ledger: "one line per delegated step, naming the role and the `providerInstanceId/model` it ran on, or `in-thread: <reason>`" (`CP:110`).
- Before replacing an abandoned agent whose writes could overlap, `task_cancel` it and read `task_status` until terminal with no `hasPendingChildRuns` (`CP:102`).
- Before committing from a worktree, stop every live agent holding it, because "A delegate's children do not inherit its brief, so a read-only instruction never reaches them" (`C:plugins/pstack/skills/poteto-mode/playbooks/opening-a-pr.md:5`).

Review gates:

- Bug fix, Feature and Refactoring diffs run `interrogate` before opening a PR; only Act-on findings block, nits are batched or dropped with reasons, later rounds review only the fix diff, a verifier runs the real artifact after each fix round, and three fix rounds is the cap (`CP:24`).
- "A review gate stays closed when no independent reviewer can run": a failed reviewer is replaced, the agent's own review, tests or CI never count, and the todolist records `BLOCKED: independent review` (`CP:108`).
- The arena cross-judge must be a pool entry "whose model ran no candidate, so no model scores its own work" (`C:plugins/pstack/skills/arena/SKILL.md:28`).
- Autopilot-full verifiers are assigned round-robin over the `interrogate reviewers` entries so lanes span model families (`C:plugins/pstack/skills/poteto-mode/playbooks/autopilot-full.md:14`).

PR shepherding:

- `C:plugins/pstack/skills/poteto-mode/scripts/watch-pr/settle.ts` (406 lines) holds READY until accounts other than the author and the `gh` viewer have been quiet for 300 seconds since the latest push, opening or ready-for-review, and up to 30 minutes while an `eyes` reaction is open; it names no bot.
- Babysit `drive` loops `watch-pr --timeout 540` inside the turn, stops after two hours unchanged or three in total, and arms `watch_pull_request` only for a human-review wait (`C:plugins/pstack/skills/poteto-mode/playbooks/babysit.md:12`).
- Shipping merges with `--match-head-commit <head>` (forked from pstack-claude, `C:tools/forks.json`), which we already do.
- Three watch-pr bug fixes from pstack-claude: STALE checks read as failed, no-CI repos get a verdict, and a BLOCKED frontier is confirmed for 60 seconds (`C:CHANGES.md:56-59`).

Smaller rules: load a managed platform's skill before running its CLI (`CP:34`); a todolist fallback at `.audit/<task-slug>.todo.md` when the host has no task tool (`CP:132`); on Codex, read poteto-mode "whole before acting, in a shell call of its own with `max_output_tokens: 10000`" (`CP:10`).
Added skills: thermos and its two review agents, and six cursor-team-kit skills (`deslop`, `fix-ci`, `fix-merge-conflicts`, `get-pr-comments`, `make-pr-easy-to-review`, `what-did-i-get-done`).

### 2.3 How it maps pstack onto T3

| Need | chhoumann mapping | Where |
|---|---|---|
| Subagent, swarm worker, panel seat | `delegate_task`, `mode: "async"`, `target` from the sheet | `CP:104`, `C:plugins/pstack/skills/swarm/SKILL.md:30` |
| Persona agents | brief opens "Read `<plugin root>/agents/<name>.md` in full and act as it says" | `CP:104` |
| Read-only reviewer | `role: "review"` plus an inspect-only sentence | `C:plugins/pstack/skills/interrogate/SKILL.md:35` |
| Autopilot PR owner | top-level thread via `t3_thread_launch` with a worktree `workspaceStrategy`, reporting back with `t3_thread_send` | `C:plugins/pstack/skills/poteto-mode/playbooks/autopilot-full.md:8` |
| Hourly audit | `schedule_task` interval bound to the thread, `nextRunAt` reported, deleted at the end | same file `:22` |
| Autonomous wake | `schedule_task` with a titled run, event watcher subagent plus heartbeat | `C:plugins/pstack/skills/poteto-mode/playbooks/autonomous-run.md:6` |
| Store | `${XDG_STATE_HOME:-~/.local/state}/t3-pstack/` | `C:plugins/pstack/skills/poteto-mode/playbooks/orchestrate.md:23` |
| History | `t3_thread_list` by `updatedAt`, `t3_thread_search`, `t3_thread_read` with `maxCharsPerItem` | `C:plugins/pstack/skills/recall/SKILL.md:15-19` |
| UI evidence | project verify skill first, else `preview_*` or `device_*` | `CP:30` |

Model selection is policy as data: `C:plugins/pstack/models.json:1-30` defines three tiers (default Opus 5.5 xhigh, strongest Fable 5.1 xhigh, a panel of Opus, `codex/gpt-6.1-sol` and `grok/grok-4.7`), and each role names a tier.
The sheet lives at `~/.config/t3-pstack/models.md`, one per machine, because provider instance IDs differ per machine (`C:CHANGES.md:21`).
`C:plugins/pstack/skills/setup-pstack/scripts/t3-sheet.mjs` validates the grammar `<providerInstanceId>/<modelId> <optionId>=<value>`, checks entries against an `orchestrator_capabilities` dump, and rejects a panel with fewer than two families (`:118`).
Its family rule is the model ID's prefix, not the provider: "a Claude model served by a Codex-driver pool still counts as Claude" (`t3-sheet.mjs:38-42`).

Routing: chhoumann drops `disable-model-invocation` from poteto-mode alone, and a session-start hook (`C:plugins/pstack/hooks/session-start-context.md:1-17`) tells every chat to invoke poteto-mode when a task touches more than one file, involves a design choice, or is a bug of unknown cause, unless the sheet says `session hook: off` (`C:plugins/pstack/hooks/session-start.sh:30-32`).

### 2.4 Memory and self-improvement

No new mechanism beyond upstream.
reflect finds this session's own transcript by `$CLAUDE_CODE_SESSION_ID` or `$CODEX_THREAD_ID` through two scripts, so it never picks a sibling chat with the same opening prompt (`C:plugins/pstack/skills/reflect/SKILL.md:16-31`).
show-me-your-work's end-of-run audit reads the run's own thread and each child's thread with `t3_thread_read` (`C:plugins/pstack/skills/show-me-your-work/SKILL.md:57`).
The port's real self-improvement is its changelog: most releases cite an audit of real runs, for example "An audit of five days of t3-pstack delegation, about $2.6k at API prices, found roughly 40% of it wasted, mostly in how implement, review, and fix loops ran" (`C:CHANGES.md:199`), and "the most common failure, about 121 of 227 flaw instances, was declaring a PR ready once CI turned green but before review bots ... had posted" (`C:CHANGES.md:207`).

### 2.5 Clever, simple, or wrong

Clever:

- Measured economics: verifiers that ran the real artifact after each fix "returned the most per dollar", and the full panel re-reviewing small fix diffs was waste (`C:CHANGES.md:199-203`).
- The settle window solves "bots post after CI goes green" without a per-bot list (`C:CHANGES.md:205-216`).
- The Codex read budget: "Codex picks each shell read's output budget, and for a `SKILL.md` it usually picks 3000 to 6000 tokens", which cut the middle of poteto-mode in two of three runs (`C:CHANGES.md:43`).
- Self-judging guard, born from a run where "GPT-6-Astra [was] both a runner and the cross-judge, and the judge picked Astra's own design" (`C:CHANGES.md:249`).
- The schedule_task backstop was removed because it "survived a user Stop and resumed babysitting ... could fire during a running turn or be created twice" (`C:CHANGES.md:223`), a useful warning about persistent timers.

Wrong or heavy:

- Weight: 173 regex rules, forks, a network-fetching frozen-hooks check in CI, and an installer that writes Codex trust hashes into `config.toml` (`C:CHANGES.md:17`, `C:CONTRIBUTING.md:84`); the opposite of simple.
- It never pins T3's contract, so its T3 claims are untested: "Not yet tried live: `watch_pull_request` on a real PR ... and the `device_*` tools" (`C:CHANGES.md:236`).
- It ignores T3's `isolation: "worktree"`: writing children get a parent-made `git worktree add` (`CP:106`), which skips T3's project setup and leaves cleanup to the parent.
- Reflect still reads JSONL by file path (`C:plugins/pstack/skills/reflect/SKILL.md:20`), where pmwoz found that "Trail reviewers received JSONL paths" was a failure (commit `d788ba9`).
- `poteto-agent` with no path picks the highest-versioned poteto-mode in the whole plugin directory (`C:plugins/pstack/agents/poteto-agent.md`), which pmwoz warns against because "other pstack ports install there with higher versions" (`PA:11`).
- The session hook auto-routes every multi-file task into poteto-mode with an `<EXTREMELY_IMPORTANT>` block (`C:plugins/pstack/hooks/session-start-context.md:1`); Bryce runs `session hook: off` and rejected the hook (`O:docs/plans/hzbook-pstack-takeover.md:172`).

## 3. The two ports compared

| Axis | pmwoz | chhoumann |
|---|---|---|
| Philosophy | upstream verbatim, one adapter | upstream rewritten in place |
| Files differing from upstream | 5 changed plus additions | 53 changed plus 19 added |
| Upstream lag | 1 commit (`1e5c90a`) | none (`6ce45c5`) |
| T3 contract tracking | snapshot, tool-name lint, daily watch | none |
| Tooling lines (non-test) | about 530 | about 3,800, including the 1,063-line rule file |
| Install | two CLI commands per provider | `npx` installer plus `doctor` across all homes |
| Builders and owners | fresh `delegate_task` per round, root owns every PR | autopilot owners as `t3_thread_launch` threads |
| Writing worktrees | T3 `isolation: "worktree"` | parent-made `git worktree add` |
| PR waiting | `watch_pull_request` plus `watch-pr --status-only` | `watch-pr` loop inside the turn, `watch_pull_request` only for human review |
| Model family | provider instance | model ID prefix |
| Default panel | Claude plus GPT | Claude, GPT and Grok |
| Review gate before PR | upstream's (none mandatory) | interrogate, bounded at three rounds |
| Evidence of what works | two audits in commit messages | per-release audits in `CHANGES.md` |

pmwoz is the better model for staying in sync cheaply and for knowing what T3 can do.
chhoumann is the better model for review policy and for recording why each rule exists.
Both agree on T3 facts we also rely on: a child cannot call `watch_pull_request` (T3's own text: "A subagent cannot watch: its parent thread owns the pull request", `P:t3/contract/apps/server/src/mcp/toolkits/pullRequests/tools.ts:324`), completions wake the parent, and `schedule_task` replaces `/loop`.
They disagree on `watch_pull_request`, and our data sides with chhoumann's caution.

## 4. The ports against our system

Our system is a compiled pair of skills (`O:.agents/skills/hzbook-coordinator/SKILL.md`, 277 lines; `O:.agents/skills/hzbook-cos/SKILL.md`, 211 lines) plus about 3,600 lines of scripts under `O:orchestrate/`, where scripts own state and refuse illegal moves.
Neither port reaches that layer: they run pstack's prose playbooks on top of upstream's `orch.ts` bookkeeping.

Where we are already aligned with the better of the two:

- Checkers run as `delegate_task` children with `isolation: "worktree"`, `mode: "async"` and a stable `clientRequestId` (`O:.agents/skills/hzbook-coordinator/SKILL.md:108-109`), and each switches to the frozen head and keeps evidence outside its worktree (`O:orchestrate/coordinator/templates/checker-brief.md:9-10`, `:56`), which is pmwoz's `PA:68-69`.
- Builders are top-level `t3_thread_launch` threads (`O:.agents/skills/hzbook-coordinator/SKILL.md:83`), as chhoumann's autopilot owners are.
- Liveness is judged by side effects, and a stalled builder is interrupted and confirmed stopped before its replacement (`:188-192`), which matches chhoumann's stop-before-replace rule (`CP:102`).
- Models are pinned per phase and printed by scripts, so the agent never chooses (`O:.agents/skills/hzbook-coordinator/SKILL.md:15`); that is a stronger form of chhoumann's dispatch ledger.
- A provider that is down falls back with "reduced diversity" noted (`:110`), as pmwoz's `PA:54` does.
- `--match-head-commit` on merges (`:141`), and approvals as rows instead of relayed words (`:133`).

Where they contradict us, with the evidence:

- `watch_pull_request`: pmwoz relies on it, we forbid it (`O:.agents/skills/hzbook-coordinator/SKILL.md:210-211`), and our measurement on drafts is the only live data in any of the three repos.
- Owners as threads versus fresh delegates: pmwoz follows T3's injected rule to launch threads only on explicit request (`P:t3/contract/packages/provider-core/src/server/orchestrationInstructions.ts:10`); our design was Bryce's explicit choice, so the rule is satisfied.

A stale fact in our own plan, surfaced by pmwoz's contract snapshot:

- `O:docs/plans/hzbook-pstack-takeover.md:135` says "Builders do not use T3's `delegate_task`: a delegated child shares the coordinator's checkout, since delegation has no worktree option", and `:172` rejects "`delegate_task` for builders (no worktree option)".
- T3's contract now has `isolation: "worktree"` (`P:t3/contract/packages/contracts/src/orchestratorMcp.ts:177-182`), and our checkers already use it.
- The remaining reasons builders stay threads are real (a child cannot watch or own a PR, and the builder reuse that run 7 measured), but the recorded reason is wrong and the next review will trip on it.

Where they do something we lack:

- A pinned T3 contract with a tool-name lint and a change report (pmwoz).
  A one-off comparison for this report found that all 17 T3 tools our skills and `orchestrate/` sources name exist at pmwoz's pin `f99b202`, so the check would pass today at no cost.
- A family rule by model prefix and a panel-diversity check (chhoumann).
- A Codex read-budget rule (chhoumann).
  Our GPT-seat briefs run 11 to 18 KB, about 2,700 to 4,600 tokens (`~/.claude/orchestrate/hzbook/runs/2026-10-14-ci-train/briefs/i984-r5-review-gpt.md` is 18,484 bytes), inside the 3,000 to 6,000-token range in which chhoumann saw Codex cut file middles.
- A fix-diff-only review rule for later rounds, with a verifier after each fix (chhoumann `CP:24`); our narrower-lane rule applies only when product code is unchanged (`O:.agents/skills/hzbook-coordinator/SKILL.md:107`).
- A bot-agnostic settle window (chhoumann `settle.ts`); our profile lists review bots by name (`O:orchestrate/README.md`, profile `review bots`).
- A no-self-judging rule for design panels (chhoumann arena `:28`); our deep tickets run `pstack:architect` with no stated judge rule (`O:.agents/skills/hzbook-coordinator/SKILL.md:80`).

Memory and self-improvement, compared:
Our lessons loop (on-demand passes, `replay.sh` on real store data, rulings and findings files) is more structured than either port, which keep only upstream's reflect and recall.
One thing to borrow: our `lessons.mjs` reads T3's private `statev2.sqlite` (`O:orchestrate/cos/bin/lib.mjs:8`, plan `O:docs/plans/hzbook-pstack-takeover.md:187-188`), while pmwoz passes thread IDs and reads through `t3_thread_read` (`PA:91-92`), which survives a T3 schema change.

## 5. Ideas worth stealing, ranked

1. **Pin T3's tool contract and lint our skills against it.**
   What: snapshot T3's toolkit and contract files at a commit, fail the build on any backticked T3 tool name our sources use that the snapshot does not define, and report tools added or removed when the pin moves.
   Where: `P:tools/check.ts:57-68`, `P:tools/lib.ts:122-138`, `P:tools/t3.ts:19-49`, `P:tools/watch.ts:22-65`.
   Why: it closes our own housekeeping item "pin T3's tool names like the model catalog with a test over both skills" (`O:docs/plans/hzbook-pstack-takeover.md:175`), would have flagged the stale "no worktree option" fact, and is about 150 lines in `O:orchestrate/build.mjs --check`.
2. **Count model families by model ID, and require panels to span two.**
   What: `family = model.split("/").pop().split("-")[0]`, and `models.mjs --check` rejects a GPT lane that resolves to a Claude model.
   Where: `C:plugins/pstack/skills/setup-pstack/scripts/t3-sheet.mjs:38-42`, `:118`.
   Why: our diversity claim rests on the `review-gpt` lane (`O:docs/plans/hzbook-pstack-takeover.md:54-62`); a fallback or sheet edit that silently turns it into Claude is exactly the error a family check catches, and provider-instance families (pmwoz `PA:58`) would miss it under `claudeAgent_claude_proxy`.
3. **Tell the Codex seat to read its brief whole.**
   What: the GPT checker's task line says to read the brief in one shell call with `max_output_tokens: 10000`, and re-read if output shows truncation, plus a build check that briefs stay under that budget.
   Where: `CP:10`, evidence `C:CHANGES.md:43`.
   Why: our largest GPT brief is about 4,600 tokens, inside the range where Codex cut file middles in two of three runs; the GPT seat is the one lane Bryce relies on for a second family.
4. **Review only the fix diff in later rounds, and batch nits.**
   What: round 1 reviews the whole change; later rounds review the fix diff; nits never block and are batched into one final run or dropped with a reason; a verifier drives the real artifact after each fix.
   Where: `CP:24`, evidence `C:CHANGES.md:197-203`.
   Why: chhoumann measured about 40% waste in review and fix loops at $2.6k over five days; our checker rounds re-run every lane on the whole PR unless product code is unchanged, so this is our largest likely cost lever, to be checked against `O:docs/plans/hzbook-run-results.md` before adopting.
5. **No model judges its own candidate.**
   What: in any design panel, the judge comes from a model that produced no candidate.
   Where: `C:plugins/pstack/skills/arena/SKILL.md:28`, evidence `C:CHANGES.md:247-251`.
   Why: one sentence in our deep-ticket design step (`O:.agents/skills/hzbook-coordinator/SKILL.md:80`) prevents a failure chhoumann saw live.
6. **A bot-agnostic review settle window.**
   What: hold merge-ready until accounts other than the author have been quiet for five minutes since the last push, longer while an `eyes` reaction is open.
   Where: `C:plugins/pstack/skills/poteto-mode/scripts/watch-pr/settle.ts`, evidence `C:CHANGES.md:205-216`.
   Why: it replaces a per-bot list in the profile with one rule that covers bots we add later; worth it only if our runs show a bot posting after merge-ready, which the run results should say.
7. **Read chats through T3, not its database.**
   What: give the lessons thread thread IDs and have it read them with `t3_thread_read`, keeping the SQLite read only as a fallback.
   Where: `PA:91-92`, failure noted in pmwoz commit `d788ba9`.
   Why: removes our dependency on T3's private schema named as an open item (`O:docs/plans/hzbook-pstack-takeover.md:187-188`).
8. **Record the omit-`runtimeMode` and capabilities-overflow facts.**
   What: never pass `runtimeMode` on `delegate_task` (narrower modes stall on approvals), and query an oversized `orchestrator_capabilities` result from its saved file with `jq`.
   Where: `PA:28`, `PA:55`, T3's own description at `P:t3/contract/packages/contracts/src/orchestratorMcp.ts:194-200`.
   Why: our skills omit it today by accident, not by rule; one line in the checker launch step keeps a future edit from stalling every checker.
9. **Fix the stale reason in our plan.**
   What: rewrite `O:docs/plans/hzbook-pstack-takeover.md:135` and the `:172` rejection to give the real reasons builders stay threads (PR ownership and watching, builder reuse), not the missing worktree option.
   Where: our own plan, with T3's schema at `P:t3/contract/packages/contracts/src/orchestratorMcp.ts:177-182`.
   Why: the "Rejected" list exists so the next review does not relitigate; a false premise in it invites exactly that.
