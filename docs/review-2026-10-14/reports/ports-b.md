# pstack ports to T3 Code, batch B: mariusflorescu/pstack-t3, Tr1Fecta-7/p3-stack, uzairansaruzi/p3-stack

Read-only review, 2026-10-14.
No script from any target was run; every claim below comes from reading files, `git log`, and `diff`.

Path aliases used throughout:

| Alias | Path | Commit |
|---|---|---|
| `M/` | `/tmp/agent-research/mariusflorescu_pstack-t3/repo/` | 9f0e440 |
| `T/` | `/tmp/agent-research/Tr1Fecta-7_p3-stack/repo/` | 8cdef15 |
| `Z/` | `/tmp/agent-research/uzairansaruzi_p3-stack/repo/` | 09909eb |
| `U/` | `/tmp/agent-research/cursor_plugins/repo/pstack/` | 850d7f2 (pstack 0.15.25) |
| `T3/` | `/tmp/agent-research/pingdotgg_t3code/repo/` | 339179f5 (2026-10-15) |
| `AC/` | `/home/bryce/git/agent-configs/` | d46eabd |

## Headline findings

1. Two of the three targets are one lineage: Tr1Fecta-7/p3-stack is a fork of uzairansaruzi/p3-stack, sharing its two commits by SHA (c4824d3, 09909eb, both 2026-10-05, author Uzair Ansar) and adding 15 more (`git log` in `T/` and `Z/`).
   Uzair's repo is the frozen initial port of pstack 0.15.10 (`T/CHANGES.md:133-135`); Tr1Fecta's is the maintained one.
2. A prior review on 2026-10-13 already compared marius and Tr1Fecta (with pmwoz, against upstream 0.15.23) and took six items (`AC/docs/plans/hzbook-pstack-takeover.md:150-172`).
   Since then marius synced three times (851a213, 564759a, 9f0e440) and Tr1Fecta twice (c8024a1, 8cdef15); beyond mapping upstream's new effort rule onto `delegate_task.target.options`, neither added a T3 mechanism, so the new value here is a source check of their T3 claims and the gaps they expose in our own skills.
3. marius is a diff-faithful port with an enforced translation contract (`M/T3-NATIVE.md`, 140 lines) and a 190-line lint (`M/scripts/check-t3-native.mjs`) that fails the build on any Cursor mechanism left in skill text.
   It is the best-engineered of the three and is current with upstream HEAD (`M/UPSTREAM:3`).
4. p3-stack (both repos) is a per-file rewrite by delegated workers (`Z` commit 09909eb message: "One delegated worker per skill and playbook"), and Tr1Fecta's later parity pass found it had silently dropped upstream rules (`T/CHANGES.md:65-84`).
5. Checked against T3's source, p3-stack has three wrong mechanics that marius gets right: waiting for a merge wake that T3 never sends, autopilot owners as child tasks that T3 forbids from watching PRs, and a store inside the repo that worktrees do not share (sections 3.5 and 4).
6. Tr1Fecta's most valuable artifact is a measured harness bug with a recovery signature: a delegate that ends with a background process running stays `running` with `workState: "waiting_for_children"` and `latestTerminalStatus: "completed"`, and its report is lost (`T/CHANGES.md:63`, `T/skills/p3-mode/SKILL.md:99`).
   We took the prevention on 2026-10-14 (`AC/docs/plans/hzbook-pstack-takeover.md:166`) but not the recovery, and our audit tick cannot see that state (section 6).
7. Our four generated orchestrate skills set `disable-model-invocation: true` but ship no `agents/openai.yaml`, which marius probed Codex to ignore and replace (`M/T3-NATIVE.md:22-23`); our Codex GPT checker runs with those skills in `~/.agents/skills` (section 6).
8. One T3 fact our rejections rest on has moved: `delegate_task` gained `isolation: "worktree"` on 2026-10-14 (`T3/packages/contracts/src/orchestratorMcp.ts:177-181`, T3 commit 25629a76, #19102), so "`delegate_task` for builders (no worktree option)" in our rejected list (`AC/docs/plans/hzbook-pstack-takeover.md:172`) now has a stale reason, though builder reuse still argues for threads.

## 0. Lineage and scope

- `Z/` has 2 commits and 113 files; `T/` has 17 commits and 123 files; `M/` has 8 commits and 194 files (`git log`, `git ls-files`).
- Tr1Fecta credits the port to Uzair in `T/CHANGES.md:135` and fixes a link that still pointed at `uzairansaruzi/p3-stack` (`T/CHANGES.md:82`).
- Upstream's git history in the clone is shallow (81 commits, back to 0.15.20 at 1b6d44f), so `Z/` was diffed against 0.15.25 and its stale parts attributed through `T/CHANGES.md`.

Size, skills directory only (markdown plus TSV lines, then non-test script lines, then skill count):

| Tree | Markdown lines | Script lines | Skills |
|---|---|---|---|
| `U/skills` | 4,869 | 5,283 | 54 |
| `M/skills` | 4,932 | 5,014 | 55 (adds bundled `deslop`) |
| `T/skills` | 4,812 | 358 | 55 (adds `p3-agent`) |
| `Z/skills` | 5,108 | 42 | 51 (no `ketchup`, `sharpen`, `in-your-own-words`) |
| `AC/orchestrate` (ours, whole tree) | 4,378 lines total | | 2 skills per project |

## 1. mariusflorescu/pstack-t3

### 1.1 What it is

- Purpose: upstream pstack's 52 skills for Claude Code and Codex threads under T3, keeping upstream names (`poteto-mode`, `setup-pstack`) and wording (`M/README.md:3`, `M/AGENTS.md:9-10`).
- Install: `npx skills add mariusflorescu/pstack-t3 -g -a claude-code -a codex`, which copies into `~/.agents/skills/` and symlinks `~/.claude/skills/` (`M/README.md:8-11`); needs `gh` and Bun for the `orch` and `watch-pr` scripts (`M/README.md:13`).
- Sync: `M/UPSTREAM:1-4` pins repo, path, SHA and the bundled `deslop`; `M/AGENTS.md:15-17` says to diff upstream from the pin, apply each hunk through the contract, run the checker and `bun test`, then bump the pin.
- Cadence: five sync commits, four of them committed between 07:01 and 07:10 local time on consecutive mornings (633f14a 10-11, 2cf8ceb 10-12, 564759a 10-14, 9f0e440 10-15), which reads as a scheduled agent; the repo does not say so.
- Lag: at 850d7f2, which is upstream HEAD (`M/UPSTREAM:3`).

### 1.2 Delta from upstream, by theme

Apart from `make-bot-ui` (115 to 92 lines) and the scripts, each skill file changes by a few lines; the substantive changes are:

- Skill references become file reads.
  Every skill that names another carries a standard sentence saying `**name**` means `../<name>/SKILL.md`, because user-only skills cannot be loaded by the skill tool (`M/T3-NATIVE.md:41-42`, `M/skills/poteto-mode/SKILL.md:12`).
- Subagents become `delegate_task` with fixed defaults: `mode: "async"`, a role-naming `title`, a `clientRequestId` stable per round, runtime mode inherited, and "read-only" written in the brief rather than a weaker mode so MCP tools stay (`M/skills/poteto-mode/SKILL.md:95`, `M/T3-NATIVE.md:63`).
- `poteto-agent` becomes brief text, `M/skills/poteto-mode/references/poteto-agent.md:3`, pasted at the top of every delegate brief with the absolute path of `poteto-mode/SKILL.md` filled in (`M/T3-NATIVE.md:90`), because a `/name` at the start of a brief does not load a user-only skill (`M/T3-NATIVE.md:22`).
- Model slugs become roles in `~/.config/pstack/pstack-models.md`, `<providerInstanceId>/<model> (<effort>)`, mapped to `delegate_task.target` with the effort option id each model lists (`M/skills/poteto-mode/SKILL.md:97`, `M/T3-NATIVE.md:71-83`).
- Effort and speed: start from the role, raise one step for the hardest work, lower for routine; fast mode only when CI or trunk is red or a person is blocked, as `fastMode: true` on Claude or `serviceTier: "priority"` on Codex (`M/skills/poteto-mode/SKILL.md:99`).
- Loops become T3 waits: `/loop` maps to `watch_pull_request` for PR events and `schedule_task` for cadence, "arm it and end the turn" (`M/T3-NATIVE.md:98`).
- `watch-pr` loses its poll loop: policy.ts drops from 836 to 553 lines and cli.ts from 223 to 172, the `--interval`, `--timeout` and `--max-query-errors` options are gone, and each run reads GitHub once and prints a verdict, exit 5 for `WAITING` (`M/T3-NATIVE.md:123`, `diff U/.../watch-pr/cli.ts M/.../cli.ts`).
- `orch` loses Graphite and the Origin forge: `frontier set --chain <file>` parses a saved `list_thread_pull_requests` result instead of walking `gh pr list` (store.ts grows from 1,677 to 1,758 lines; `M/T3-NATIVE.md:100,124`).
- The orchestrate store moves outside every worktree, to `~/.local/state/pstack/orchestrate/<project-slug>/`, with `ORCH_STORE` set on every call because shell state does not persist (`M/skills/poteto-mode/playbooks/orchestrate.md:23,62`).
- Transcripts become threads: `recall`, `reflect` and `automate-me` page `t3_thread_list`, use `t3_thread_search` as "a bounded hint, not an index", and read `t3_thread_read` with `view: "activity"` (`M/T3-NATIVE.md:103`, `M/skills/recall/SKILL.md:21`, `M/skills/reflect/SKILL.md:17`).
- Codex parity: every user-only skill ships `agents/openai.yaml` with `policy.allow_implicit_invocation: false` (`M/skills/poteto-mode/agents/openai.yaml:1-2`, `M/T3-NATIVE.md:47`).
- Bundles `deslop` from cursor-team-kit (`M/skills/deslop/SKILL.md`, 22 lines) so "before commit" still strips code slop (`M/skills/poteto-mode/SKILL.md:28`).
- Not ported: Benny automations, the Cursor guide, the plugin manifest (`M/README.md:80`).

### 1.3 How it maps pstack onto T3

| pstack need | marius's T3 mechanism | Evidence |
|---|---|---|
| Subagent, swarm worker, panel seat | `delegate_task` child, one per panel entry, target per role | `M/T3-NATIVE.md:63-67,79-82` |
| Writer needing its own tree, PR owner, sub-coordinator | `t3_thread_launch` with a worktree `workspaceStrategy`, `modelSelection` with `instanceId` | `M/T3-NATIVE.md:67`, `M/skills/poteto-mode/playbooks/orchestrate.md:16` |
| Background wait | end the turn; child completion wakes the parent | `M/T3-NATIVE.md:65` |
| Recurring audit | `schedule_task` interval, `run_scheduled_task_now` for a tick, pause with `update_scheduled_task enabled:false` | `M/skills/poteto-mode/playbooks/autopilot-full.md:22-23`, `orchestrate.md:73` |
| PR shepherding | `watch_pull_request`, one-shot `watch-pr` per wake, `unwatch_pull_request` on every stop | `M/skills/poteto-mode/playbooks/babysit.md:12` |
| Merge wait | `watch_pull_request` plus one fallback 5-minute `schedule_task`, because a merge ends the watch without a wake | `M/skills/poteto-mode/playbooks/shipping.md:9` |
| Stack order | `link_pull_request` every layer, `list_thread_pull_requests` | `M/skills/poteto-mode/playbooks/opening-a-pr.md:28` |
| Questions | ask in the thread; `t3_pending_request_*` for other threads | `M/T3-NATIVE.md:105` |
| Secrets, webhooks | `request_secret` then `signature.secretRef`; `schedule_task {"type":"webhook"}` with `{{body.path}}` | `M/T3-NATIVE.md:114-115`, `M/skills/make-bot-ui/SKILL.md:15-30` |
| Visuals | `html_preview` then `html_render` | `M/T3-NATIVE.md:116` |
| Restart | threads, tasks, schedules and watches persist; reattach with `t3_thread_list`, `task_status`, `list_thread_pull_requests` | `M/T3-NATIVE.md:104` |
| Todo list | harness task tool, else `~/.local/state/pstack/checklists/<repo>-<branch>.md` | `M/skills/poteto-mode/SKILL.md:127` |
| Providers | `orchestrator_capabilities` with `canRunChildTask`; no file means panels take the parent plus the strongest model of each other provider, up to three | `M/skills/setup-pstack/SKILL.md:14,29`, `M/T3-NATIVE.md:82` |

Cursor and Grok: no provider-specific handling; the checker bans `grok-`, `claude-*-N`, `gpt-N` and `composer-` slugs from skill text so roles are the only way to name a model (`M/scripts/check-t3-native.mjs:21`).

### 1.4 Memory and self-improvement

- No new memory layer: `recall` still rebuilds context from history each time, now from T3 threads (`M/skills/recall/SKILL.md:21`).
- `reflect` routes learnings to skill edits through `skill-creator` when installed, else the Authoring-a-skill playbook (`M/skills/reflect/SKILL.md`, diff vs `U/`).
- Self-improvement of the port itself is structural: the contract's harness-facts table is dated and says "Re-probe before changing a rule that rests on one" (`M/T3-NATIVE.md:13`), and the checker turns each translation rule into a lint whose message names the fix (`M/scripts/check-t3-native.mjs:15-35`).

### 1.5 Clever, and wrong

Clever:

- The checker's rule table pairs each banned regex with a hint naming the T3 replacement, exempts code files from prose-only rules, verifies that every bold skill name resolves to a directory, that no relative link escapes `skills/`, and that `disable-model-invocation` and `openai.yaml` agree (`M/scripts/check-t3-native.mjs:15-40,49-60,121-140,142-176`).
- The harness-facts table distinguishes Claude Code from Codex per fact, including that installing a skill both globally and per project makes Codex load neither (`M/T3-NATIVE.md:15-27`, `M/README.md:11`).
- Shipping knows a merge ends a T3 watch silently and adds exactly one fallback schedule, reused across frontiers and deleted on stop (`M/skills/poteto-mode/playbooks/shipping.md:9-10`).
- Babysit triages what already exists before arming, since only comments posted after arming wake the thread, and reruns the verdict after its own resolutions, which wake nothing (`M/skills/poteto-mode/playbooks/babysit.md:12`).

Wrong or weak:

- Launched PR owners and sub-coordinators "report to the root" (`M/skills/poteto-mode/playbooks/autopilot-full.md:12,19`) with no mechanism: `autopilot-full.md` contains no `t3_thread_send`, and a launched thread's end does not wake its launcher, so reports surface only at the hourly audit tick (`autopilot-full.md:22`).
- "`delegate_task` children share your checkout" (`M/skills/poteto-mode/SKILL.md:101`, `M/T3-NATIVE.md:67`) was true at the 2026-10-10 probe and is stale since T3 added `isolation: "worktree"` on 2026-10-14 (`T3/packages/contracts/src/orchestratorMcp.ts:177-181`).
- Mapping PR owners and sub-coordinators to `t3_thread_launch` goes against T3's own instruction to launch top-level threads "only when the user explicitly asks" (`T3/packages/provider-core/src/server/orchestrationInstructions.ts:10`); it works, but T3 may push models toward child tasks.
- Fast mode on urgency spends more without the user choosing it; Tr1Fecta rejected the same upstream rule for cost (`T/CHANGES.md:20`).

## 2. uzairansaruzi/p3-stack (the root)

### 2.1 What it is

- Purpose: "pstack rebuilt for T3 Code", renaming `poteto-mode`, `poteto-agent`, `poteto-help`, `setup-pstack` to `p3-mode`, `p3-agent`, `p3-help`, `setup-p3` (`Z/README.md:3`, `Z/AGENTS.md:26`).
- Install: `./install.sh` symlinks `skills/*` into `~/.agents/skills/`, or a project's with `--project` (`Z/install.sh:5-9`, `Z/README.md:17-22`).
- Sync: none; two commits on 2026-10-05 from pstack 0.15.10 (`T/CHANGES.md:133-135`), now 15 releases behind.
- Method: one delegated worker per file, briefed to "Write only that file ... run no git commands" and to make each file "shorter than the pstack source" (`Z/AGENTS.md:9,69`; commit 09909eb).

### 2.2 Delta and T3 mapping

- The map is a 15-row table (`Z/AGENTS.md:13-27`): `Task` to `delegate_task` with `task_status` to drain, cloud agents to child tasks, worktrees to `t3_thread_launch`, `/loop` and `watch-pr` to `watch_pull_request`, hourly ticks to `schedule_task`, `gt` to `link_pull_request`, transcripts to `t3_thread_read`/`t3_thread_search`, `control-ui` to `preview_*`/`device_*`, model slugs to roles in `p3-models.md`.
- It drops every upstream script (`orch`, `watch-pr`, `check-plan.mjs`, `worktree-audit.sh`); only `show-me-your-work/scripts/log.sh` (42 lines) remains.
- Its definition of done is a grep for banned words, not a checker (`Z/AGENTS.md:66-70`).
- Memory and self-improvement: unchanged from upstream apart from the transcript-to-thread swap.

### 2.3 Wrong (all later fixed by Tr1Fecta)

- `p3-mode` points delegates at `agents/p3-agent.md` (`Z/skills/p3-mode/SKILL.md:91`), which `install.sh` never installs, and that file sends the worker to `skills/p3-mode/SKILL.md`, a repo-relative path (`Z/agents/p3-agent.md:8`); fixed in `T/CHANGES.md:93`.
- `multi-phase-plan` re-reads playbooks with `git show origin/main:skills/p3-mode/...` (`Z/skills/p3-mode/playbooks/multi-phase-plan.md:29`), a path that exists only in the p3-stack repo; fixed in `T/CHANGES.md:88`.
- The README says T3 reads `~/.agents/skills/`, but Claude threads read `~/.claude/skills/` (`Z/README.md:22`); fixed in `T/CHANGES.md:91-92`.
- `swarm` says `inherit` instead of `inherit-parent` (`Z/skills/swarm/SKILL.md:25`), and four playbooks carry stray skill frontmatter (`Z/skills/p3-mode/playbooks/autopilot-full.md:1-4`); fixed in `T/CHANGES.md:80,83`.

## 3. Tr1Fecta-7/p3-stack

### 3.1 What it is

- Purpose: the maintained p3-stack, same renames, plus `p3-agent` as a real skill (`T/README.md:39`).
- Install: `./install.sh` links into `~/.agents/skills`, `--claude` adds `~/.claude/skills`, `--project` targets a repo (`T/install.sh:5-7,45-48`, `T/README.md:22-27`).
- Sync: `T/UPSTREAM:1-5` pins commit and version; `T/scripts/upstream.sh` (106 lines) caches a blobless clone and offers `status`, `files`, `diff`, `pin` (`T/scripts/upstream.sh:3-10`).
  `files` maps each upstream path to its p3 path and tags it `(not ported)` or `(new in p3-stack)` (`T/scripts/upstream.sh:32-44,54-68`).
  Every sync and every p3-only change gets a dated `CHANGES.md` entry listing ported, p3-only and skipped items (`T/AGENTS.md:67-77`, `T/CHANGES.md`, 135 lines).
- Lag: at 1e5c90a, pstack 0.15.24 (`T/UPSTREAM:4-5`), one release behind; synced through PRs #1, #8, #9, #10.

### 3.2 Delta from upstream, by theme

- Same T3 map as `Z/`, plus one row: `subagent_type: "poteto-agent"` becomes a brief that opens "Load the `p3-agent` skill first", because `delegate_task` has no agent types (`T/AGENTS.md:27`).
  `p3-agent` is model-invocable so workers can load it by name, and it finds `p3-mode` at `../p3-mode/SKILL.md` (`T/skills/p3-agent/SKILL.md:3,8`).
- Ships upstream's `check-plan.mjs` and `worktree-audit.sh` with small T3 edits; `orch` and `watch-pr` stay unported (`T/CHANGES.md:78`).
- The orchestrate store is `orchestrate/<project-slug>/` "in the current project", hand-maintained TSV and JSON (`T/skills/p3-mode/playbooks/orchestrate.md:22`).
- Models: `p3-models.md` at the project root first, then `~/.agents/p3-models.md` (`T/skills/setup-p3/SKILL.md:8`, `T/CHANGES.md:21`); fast mode only where an entry says `(effort, fast)`, never for urgency (`T/CHANGES.md:20`).
- Panels stay at one entry per detected provider, up to three, where upstream shrank `interrogate` to two (`T/CHANGES.md:127`).
- p3-only: delegates must stop every background process before reporting (`T/skills/p3-agent/SKILL.md:10`), and the parent never briefs a delegate to leave one running (`T/skills/p3-mode/SKILL.md:99`).
- p3-only: a T3 delegate "cannot take new instructions mid-run", so fix-forward goes to a fresh owner (`T/CHANGES.md:23`).

### 3.3 How it maps pstack onto T3

- Owners, verifiers, swarm workers and panel seats are all `delegate_task` children drained with `task_status` (`T/skills/p3-mode/playbooks/autopilot-full.md:8,14`, `shipping.md:5`); `t3_thread_launch` only when a worker needs its own thread or worktree (`T/AGENTS.md:17`).
- Sub-coordinators are launched threads (`T/skills/p3-mode/playbooks/orchestrate.md:16`).
- Waits: `watch_pull_request` for PRs, an hourly `schedule_task` for audits (`T/skills/p3-mode/playbooks/orchestrate.md:62,72`).
- Proof: `preview_*` and `device_*`, with recordings and screenshots as evidence (`T/skills/p3-mode/SKILL.md` triggers, `T/AGENTS.md:24`).
- No Cursor or Grok specifics; Tr1Fecta's own example entry `cursor/grok-4.6 (high, fast)` shows T3 can serve Grok through a Cursor provider instance (`T/CHANGES.md:20`).

### 3.4 Memory and self-improvement

- Skills: unchanged apart from the thread swap (`T/skills/reflect/SKILL.md:15`, `T/skills/recall/SKILL.md:15`).
- The repo's own improvement loop is `CHANGES.md`, and its p3-only entries are measured: the background-process rule was tested "with Haiku and Opus delegates, each change alone", 5 of 5 completing with only the agent rule, 2 of 5 with only the parent rule, so both were kept (`T/CHANGES.md:63`).
- The parity pass compared all 112 ported files to upstream and restored lost content (`T/CHANGES.md:69-77`), which is the evidence that per-file delegated rewrites drop rules.

### 3.5 Clever, and wrong

Clever:

- The `waiting_for_children` plus `latestTerminalStatus: "completed"` signature, with the recovery: read the result from the branch and `git status`, then `task_cancel`, which also stops the process (`T/skills/p3-mode/SKILL.md:99`).
- `upstream.sh files` turns a sync into a checklist of mapped paths (`T/scripts/upstream.sh:54-68`).

Wrong:

- "Before commit → the **unslop** skill over the diff" (`T/skills/p3-mode/SKILL.md:28`; same in `Z/skills/p3-mode/SKILL.md:26`) swaps upstream's code `deslop` for a prose skill whose description is "Cut AI tells from any writing" (`U/skills/unslop/SKILL.md:3`); `autopilot-full` still requires "the slop-strip" with nothing behind it (`T/skills/p3-mode/playbooks/autopilot-full.md:10`).
- Shipping step 5 arms `watch_pull_request` and waits "until the ceiling reads merged" (`T/skills/p3-mode/playbooks/shipping.md:9`; `Z/.../shipping.md:14` too), but T3 ends a watch on merge without a wake (section 4).
- Autopilot owners are `delegate_task` children that babysit per `babysit.md` (`T/skills/p3-mode/playbooks/autopilot-full.md:8`), and babysit arms `watch_pull_request` (`T/skills/p3-mode/playbooks/babysit.md:12`), which T3 refuses to subagents (`T3/docs/user/source-control.md:286`).
- Babysit `drive` arms the watch and ends the turn with no first triage pass (`T/skills/p3-mode/playbooks/babysit.md:12`), but T3 wakes only on comments after the watch started (`T3/apps/server/src/orchestration-v2/pullRequestWatch.ts:88-89`), so existing threads wait for a human nudge.
- The store sits inside the repo (`T/skills/p3-mode/playbooks/orchestrate.md:22`) while `autopilot-full` says to create "a run folder outside the repo" (`T/skills/p3-mode/playbooks/autopilot-full.md:12`); an in-repo store is not shared across worktrees and can be committed.
- `setup-p3` gives `reflect tooling` "the most capable model" (`T/skills/setup-p3/SKILL.md:29`) where upstream gives it the fast model (`U/skills/setup-pstack/SKILL.md:58`), a parity slip.

## 4. T3 facts the ports rely on, checked against T3 source

| Claim | Who | Source verdict |
|---|---|---|
| A merge ends a PR watch without waking the thread | marius `M/T3-NATIVE.md:35`; p3 assumes a wake | True: a closed PR posts a wake text (`T3/apps/server/src/orchestration-v2/PullRequestWatchReactor.ts:395-406`); a merged PR records and calls `ended(target, "merged")` with no text (`:527-529`); docs say watching ends on merge (`T3/docs/user/source-control.md:282-283`). |
| Subagents cannot watch PRs | marius `M/T3-NATIVE.md:34` | True (`T3/docs/user/source-control.md:286`); p3's child-task owners break on it. |
| Own-account comments never wake | marius, our skill | True (`T3/apps/server/src/orchestration-v2/pullRequestWatch.ts:89`). |
| Without required checks, any check counts and a later pass does not wake | not stated by any port | True (`pullRequestWatch.ts:65,70-72`): this is the root cause of our observation that a draft run's skipped check wakes a builder once and real CI never does (`AC/.agents/skills/hzbook-coordinator/SKILL.md:211`). |
| Comment-only wakes stop after 10 in a row | none | True (`pullRequestWatch.ts:13`, `source-control.md:282-283`). |
| Child tasks share the parent's checkout | marius `M/T3-NATIVE.md:67` | Stale: `isolation: "shared" | "worktree"` exists since 25629a76 on 2026-10-14 (`T3/packages/contracts/src/orchestratorMcp.ts:177-181`). |
| Continue a delegated round with a new `delegate_task`, never `t3_thread_send` to the child | marius, Tr1Fecta | True (`T3/packages/provider-core/src/server/orchestrationInstructions.ts:11`). |
| `t3_thread_launch` has no idempotency key; check `t3_thread_list` before retrying | ours (`AC/.agents/skills/hzbook-coordinator/SKILL.md:84`) | True (`orchestrationInstructions.ts:28`); neither port says it. |

## 5. The three ports compared

| | marius | Tr1Fecta | uzair |
|---|---|---|---|
| Upstream | 0.15.25, HEAD | 0.15.24 | 0.15.10 |
| Method | hunk-by-hunk diff through a contract | per-file rewrite, then a parity pass | per-file rewrite by delegates |
| Enforcement | `check-t3-native.mjs`, 19 rules plus link and frontmatter checks | grep list in AGENTS.md | grep list in AGENTS.md |
| Names | upstream's | `p3-*` | `p3-*` |
| Codex parity | `agents/openai.yaml` per user-only skill | none | none |
| Scripts | `orch` and `watch-pr` adapted, tests kept | `check-plan`, `worktree-audit` only | none |
| Store | `~/.local/state/pstack/orchestrate/<slug>/`, `orch` CLI with locks | in-repo, by hand | in-repo, by hand |
| PR owners | launched threads, can watch | child tasks, cannot watch | child tasks, cannot watch |
| Merge wait | watch plus fallback schedule | watch only, never fires on merge | watch only |
| Delegate brief | pasted text with absolute path | `p3-agent` skill loaded by name | uninstalled file |
| Code slop pass | bundled `deslop` | `unslop` (prose) | `unslop` (prose) |
| Owner report path | unspecified, tick only | task completion wakes root | task completion wakes root |

Verdict: marius is the one to read for T3 mechanics; Tr1Fecta is the one to read for measured harness bugs; uzair has nothing the other two lack.

## 6. Compared with our system

Ours is not a pstack port: the coordinator loads no poteto-mode playbook and replaces orchestrate's prose with scripts that refuse bad states (`AC/docs/plans/hzbook-pstack-takeover.md:153-154`).
Where the jobs overlap:

| Job | Ours | Best port |
|---|---|---|
| Store | `~/.claude/orchestrate/<project>/`, one script writer per file, idempotent keyed rows (`AC/orchestrate/README.md:49-56`) | marius's `orch` store, same shape |
| Models | JSON sheet per project, `models.mjs` prints the launch line, `--check` against a saved catalog (`AC/orchestrate/lib/models.mjs:1-12`) | marius's markdown role file, resolved by the model at spawn time |
| Wake on child end | checker child completions wake the coordinator (`AC/.agents/skills/hzbook-coordinator/SKILL.md:108-109`) | same in both |
| Wake on launched-thread report | builder messages the coordinator; facts go to `inbox.tsv`, a doorbell rings the CoS (`hzbook-coordinator/SKILL.md:89`, `hzbook-cos/SKILL.md:96-98`) | none; marius waits for the tick |
| PR events | `watch-run.sh` under Monitor, no model usage, reports merges and Bryce's comments (`hzbook-coordinator/SKILL.md:200-211`) | marius's `watch_pull_request` plus fallback schedule |
| Cadence | 20-minute coordinator tick, 30-minute CoS tick (`hzbook-coordinator/SKILL.md:177`, `hzbook-cos/SKILL.md:114`) | hourly in all ports |
| Liveness | `liveness.mjs` judges side effects (`AC/orchestrate/coordinator/bin/liveness.mjs:1-11`) | upstream's prose rule, no script |
| Self-improvement | `lessons.mjs` packs, `replay.sh` on real stores, `folded` markers (`hzbook-cos/SKILL.md:175-179`) | upstream `reflect`; Tr1Fecta's measured CHANGES entries |
| Memory | `sessions.md`, `findings.md`, `rulings.md` in the store | `recall` rebuilt from threads each time |
| Mechanical lint of skill text | `build.mjs --check` for generated-vs-source drift only | marius's contract checker |

Where we are ahead: script-enforced state, a merge gate, a main lock, a doorbell for launched threads, and a watcher that sees merges.
None of the ports has any of these, which matches the 2026-10-13 verdict.

Where the ports expose gaps in ours:

1. Codex invocation policy.
   `hzbook-cos`, `hzbook-coordinator`, `snapcaster-cos` and `snapcaster-coordinator` set `disable-model-invocation: true` and have no `agents/openai.yaml`, while most other user-only skills in `AC/.agents/skills/` do (for example `AC/.agents/skills/to-tickets/agents/openai.yaml:4-5`).
   Codex ignores `disable-model-invocation` and reads only `openai.yaml` (marius's probe, `M/T3-NATIVE.md:22-23`).
   Both hzbook skills are symlinked into `~/.agents/skills/`, which Codex reads, and our `checker.review-gpt` lane runs on Codex (`AC/config/hzbook/models.json`, phase `checker.review-gpt`).
   `AC/orchestrate/build.mjs:83` emits only `SKILL.md` and the scripts, so the fix belongs in the build.
2. A checker held open by a leftover process.
   Audit tick step 3 calls a checker stuck only when its output folder has no new file (`AC/orchestrate/coordinator/skill/080-audit-tick.md:21`).
   A checker that wrote its verdict and then ended with a process still running has a new file, never completes, and never wakes the coordinator (`T/CHANGES.md:63`); the tick reads it as alive, and only [Restart] step 3 looks for verdict files (`AC/.agents/skills/hzbook-coordinator/SKILL.md:222`).
   Prevention exists (`AC/config/hzbook/profile.json:75`, slot `checkerShutdown`), recovery does not.
3. Thread-phase effort option.
   `threadModel` always passes `options: { effort }` (`AC/orchestrate/lib/models.mjs:51-55`), while `childTarget` looks the option id up in the catalog; a Codex thread phase would need `reasoningEffort` (`M/skills/poteto-mode/SKILL.md:97`).
   Harmless today, since every thread phase is Claude.
4. A stale reason in the rejected list.
   "`delegate_task` for builders (no worktree option)" (`AC/docs/plans/hzbook-pstack-takeover.md:172`) predates T3 #19102.
   Builders should still stay threads, because the reuse that saved 1h20 in run 7 (same line) needs `t3_thread_send`, and T3 forbids continuing a child that way (`T3/packages/provider-core/src/server/orchestrationInstructions.ts:11`).
5. A stale plan line.
   The takeover plan still lists "Builders arm T3's `watch_pull_request`" as taken (`AC/docs/plans/hzbook-pstack-takeover.md:160`), while the skill now forbids it (`AC/.agents/skills/hzbook-coordinator/SKILL.md:211`); `pullRequestWatch.ts:65,70-72` explains why it never woke them.
6. Codex double install.
   marius probed that a skill present in both `~/.agents/skills` and a project's `.agents/skills` loads neither under `$<name>` (`M/T3-NATIVE.md:25`); a Codex thread opened in agent-configs sees every skill twice, once via the global symlink.
   Unverified for two symlinks to one directory.

## 7. Ideas worth stealing, ranked

1. **Ship `agents/openai.yaml` with every generated orchestrate skill, and lint the pairing.**
   What: `policy: allow_implicit_invocation: false` beside each `disable-model-invocation: true` skill, and a doctor check that the two agree.
   Lives in: `M/T3-NATIVE.md:22-23,47` and `M/scripts/check-t3-native.mjs:121-135`.
   Why: our Codex GPT checker can currently auto-load the coordinator or chief-of-staff skill mid-review; four lines in `AC/orchestrate/build.mjs` close it for every project.
2. **Recover a checker held open by a leftover process.**
   What: at each tick, for any checker task still running, look for its verdict file; when present, record it and `task_cancel` the task, and treat `workState: "waiting_for_children"` with `latestTerminalStatus: "completed"` as done.
   Lives in: `T/skills/p3-mode/SKILL.md:99`, `T/CHANGES.md:63`.
   Why: our prevention is a brief rule, and Tr1Fecta measured that each half alone fails: with only the agent rule a parent left a stuck task "not done yet" and never cancelled it, and with only the parent rule just 2 of 5 delegates stopped their server; a held checker today stalls its unit silently until a human looks.
3. **A contract lint for T3 mechanics in skill text.**
   What: a table of banned or stale patterns, each with a hint naming the replacement, run by the doctor over `AC/orchestrate/**` (for example `watch_pull_request` outside the sentence that rejects it, `AskUserQuestion` outside its ban, `/loop`, Cursor or Graphite terms, model slugs outside `models.json`).
   Lives in: `M/scripts/check-t3-native.mjs:15-35,163-166`.
   Why: it is the concrete shape of our own housekeeping candidate "pin T3's tool names like the model catalog with a test over both skills" (`AC/docs/plans/hzbook-pstack-takeover.md:175`), and it turns lessons-pass regressions into build failures.
4. **One dated harness-facts table.**
   What: every T3 behaviour a rule rests on, per runtime, with the probe date or T3 commit and "re-probe before changing a rule that rests on one".
   Lives in: `M/T3-NATIVE.md:11-37`.
   Why: our facts are spread across skill sentences and the takeover plan's probe notes, and two have already gone stale (items 4 and 5 in section 6); a table makes the T3 #19102 change a one-line diff to review, not a hunt.
5. **Use the source-confirmed watch semantics in the deferred GitHub-webhook item.**
   What: if the CoS ever replaces polling with a T3 webhook task, use `schedule_task {"type":"webhook"}`, `{{body.path}}` placeholders, and `request_secret` into `signature.secretRef` with GitHub's `X-Hub-Signature-256`.
   Lives in: `M/skills/make-bot-ui/SKILL.md:15-30`, `T3/packages/provider-core/src/server/orchestrationInstructions.ts:12-13`.
   Why: it is the exact recipe for our deferred item (`AC/docs/plans/hzbook-pstack-takeover.md:174`); note the trade, since each webhook run is a model turn where `watch-run.sh` costs none.
6. **Pass the catalog's effort option id for thread phases too.**
   What: route `threadModel` through the same `effortOption` lookup as `childTarget`.
   Lives in: `M/skills/poteto-mode/SKILL.md:97`; ours at `AC/orchestrate/lib/models.mjs:51-55`.
   Why: a two-line change that makes a Codex builder or lessons thread a sheet edit rather than a silent wrong-option launch.
7. **Measure a rule before keeping it, and record the numbers.**
   What: Tr1Fecta tests each harness rule in isolation across models and keeps the count in the changelog.
   Lives in: `T/CHANGES.md:63`.
   Why: our lessons passes already replay scripts on real stores; adding a small A/B for prose rules that claim to change agent behaviour would show which brief lines earn their tokens.

Not recommended: Tr1Fecta's `upstream.sh` and marius's daily syncs (tracking a port was rejected on 2026-10-13, `AC/docs/plans/hzbook-pstack-takeover.md:172`); p3's in-repo hand-kept store; owners as child tasks; fast mode on urgency.
