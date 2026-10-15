# pstack deep dive

Target: cursor/plugins at 850d7f2, pstack 0.15.25 (`.cursor-plugin/plugin.json:4`), 169 files.
Every path without a prefix is relative to `/tmp/agent-research/cursor_plugins/repo/pstack/`.
Paths starting `ours:` are relative to `/home/bryce/git/agent-configs/`.
Line numbers are `file:line` or `file:start-end`.

## Summary

pstack is about 4,900 lines of skill prose, 5,100 lines of TypeScript and shell, 2,200 lines of tests, a 1,100-line guide, and a dormant 1,600-line Slack automation pack.
Its orchestration and our orchestration converged on the same core: a coordinator that never writes code, one writer per branch, a TSV store with a verdict ledger keyed by PR and head SHA, gates parked with defaults, liveness judged by side effects, and the patch-id rule.
Its real advantages over our system are not in orchestration mechanics, where ours is more durable on T3, but in three other places.
First, it reviews code quality, not just correctness, with a written lens (`skills/interrogate/references/code-quality-review.md`) that our review lanes lack entirely.
Second, its self-improvement loop has filters and a structure-first ladder (`skills/reflect/references/synthesizer.md`, `skills/correct/SKILL.md`), so lessons become checks or get rejected, where our lessons passes mostly add prose.
Third, its prose is much smaller per job, because it pushes reasons out of skills and drops dated incident detail, where our generated coordinator skill is 5,892 words against pstack's 2,692-word Orchestrate playbook.
pstack has almost no memory store by design: durable memory is skill edits, repo checks, a tiered rubric file, append-only decision trails, and transcripts mined on demand.

## 1. Architecture

### Taxonomy

- **Router skill.** `skills/poteto-mode/SKILL.md` (149 lines) holds non-negotiable triggers (`:17-36`), an inline principles index (`:38-79`), autonomy rules (`:81-89`), subagent defaults (`:91-101`), reply style (`:103-115`), comment rules (`:117-119`) and the playbook index (`:121-149`).
- **Playbooks.** 23 files under `skills/poteto-mode/playbooks/`, 618 lines total, which are step lists the router copies verbatim into the todo list, never slash commands (`skills/poteto-mode/SKILL.md:123`, `skills/poteto-help/SKILL.md:115`).
  21 of them are 34 lines or fewer; `orchestrate.md` (112) and `multi-phase-plan.md` (155) are the outliers.
- **Principles.** 24 one-rule skills `skills/principle-*/SKILL.md`, 455 lines total, average 19 lines.
  Several bodies are one to three lines because the frontmatter description carries the rule (`skills/principle-encode-lessons-in-structure/SKILL.md:1-11`, `skills/principle-exhaust-the-design-space/SKILL.md:1-9`, `skills/principle-laziness-protocol/SKILL.md:1-10`).
- **Workflow skills.** 29 other skills: panels (`swarm`, `arena`, `architect`, `interrogate`), research (`how`, `why`, `recall`, `teach`, `blast-radius`), self-improvement (`reflect`, `correct`, `automate-me`), verification (`create-verification-skill`, `maintain-verification-skill`, `tdd`, `benchmark-checklist`), trail (`show-me-your-work`, `figure-it-out`), prose (`unslop`, `technical-writing`, `bro`, `ketchup`, `sharpen`, `in-your-own-words`), and setup (`setup-pstack`, `poteto-help`).
- **Agents.** `agents/poteto-agent.md` (9 lines) is the delegate wrapper that must read poteto-mode in full first (`:9`), with `is_background: true` (`:4`).
  `agents/comment-sicko.md` (32 lines) is a read-only comment-deletion reviewer that flags `MUST KILL` symbols instead of editing code (`:17`, `:28`, `:32`).
- **Scripts.** Only three runtime tools: `scripts/orch/` (store plus CLI, about 2,270 lines), `scripts/watch-pr/` (PR verdict watcher, about 2,360 lines), `scripts/check-plan.mjs` (205 lines), plus `scripts/worktree-audit.sh` (126) and `skills/show-me-your-work/scripts/log.sh` (42), all under `skills/poteto-mode/scripts/` except log.sh.
- **Automations.** `automations/benny/` is a dormant Slack triage and repro pack, deliberately not registered as skills (`README.md:266-270`, `automations/benny/skills/setup-benny/SKILL.md:9`).

### Install and activation

- Install is `/add-plugin pstack` (`README.md:15-19`); the manifest exposes only `./skills/` and `./agents/` (`.cursor-plugin/plugin.json:29-30`).
- 53 of 54 skills carry `disable-model-invocation: true`; only `setup-pstack` can load from the user's words (`skills/poteto-help/SKILL.md:41`), so nothing fires implicitly.
- `typescript-best-practices` auto-attaches by file glob with `paths: ["**/*.ts", "**/*.tsx"]` (`skills/typescript-best-practices/SKILL.md:4`).
- Persistent activation is a Cursor Custom Mode, chosen with Option+Enter (`README.md:93`); plain Enter attaches it to one message.
- Model config is one always-applied rule, `~/.cursor/rules/pstack-models.mdc`, written by `/setup-pstack` (`skills/setup-pstack/SKILL.md:8`, `:39-66`).
- Upstream defaults put code delegates on `grok-4.7-xhigh-fast` and judgment, prose and the hardest changes on `claude-opus-5-5-xhigh` (`README.md:30`, `skills/poteto-mode/SKILL.md:95`).

### How skills reference each other

- By bold name ("the **how** skill") and relative path; the router says bundled skills live at `../<name>/SKILL.md` and its absolute path goes into every delegate prompt (`skills/poteto-mode/SKILL.md:11`).
- A delegate with no path searches `~/.cursor/plugins/` for the highest-version copy (`agents/poteto-agent.md:9`).
- Principles are cited by name and the router demands "Cite only principles whose leaf SKILL.md you read this session" (`skills/poteto-mode/SKILL.md:15`).
- `unslop` rule numbers are stable ids other skills cite, and "A removed rule leaves a gap" (`skills/unslop/SKILL.md:13`).
- `show-me-your-work` owns the trail format and other skills must not restate its columns (`skills/show-me-your-work/SKILL.md:80-82`).

### Provenance note

Our install is `michael-denyer/pstack-claude` 0.9.84 (ours: `docs/pstack.md:13`), a Claude port.
Upstream 0.15.25 does not ship `deslop`, `thermo-nuclear-*`, `fix-ci` or `get-pr-comments`; it points to Cursor's `cursor-team-kit` for `deslop`, `control-ui` and `control-cli` (`README.md:242-250`).
So several pstack skills in our session come from the port, not from poteto.

## 2. Orchestration

### Spawn primitives

- Every Task call defaults to `run_in_background: true`, agent mode, file pointers not inlined context, and an explicit model per role (`skills/poteto-mode/SKILL.md:95`).
- "You own every subagent's work. Review the diff and write your own summary" (`skills/poteto-mode/SKILL.md:99`).
- Fresh subagents by default, with consolidated scope, because "Interrupt-chained resumes silently drop directives" (`skills/poteto-mode/SKILL.md:101`).
- Workers run `environment: "cloud"` unless they need the local machine (`skills/swarm/SKILL.md:30`, `skills/poteto-mode/playbooks/orchestrate.md:17`).

### Panels

- **swarm.** N workers partition slices or race one brief, declaring `first pass`, `rank all` or `best-of` before spawning (`skills/swarm/SKILL.md:20-26`).
  Reports are `PASS`, `ISSUES` or `BLOCKED` with every provable issue (`:34`).
  A result missing the SHAs and method its brief named is dropped and respawned once, then recorded as a gap that "does not count as a pass" (`:40`).
- **arena.** Same prompt to every candidate; the rubric is the picker's and hidden from candidates (`skills/arena/SKILL.md:13-18`).
  A readonly cross-judge on a different family scores while the parent reads (`:26-28`), the parent picks a base by rubric criterion (`:30-34`), and grafts one or two things by hand (`:36-40`).
  Convergence means ship the consensus; wild divergence means the frame was under-specified, so re-run instead of averaging (`:40`).
- **architect.** Ground with `how` and `why`, run arena with a runner prompt, "Design it twice" with at least two structurally distinct candidates, screen against red flags, prefer deeper interfaces (`skills/architect/SKILL.md:21-39`).
  The human checkpoint is opt-in (`:41-45`), and a scrap rule lists the patterns that condemn a sketch (`:55-75`).
  The runner prompt tells each model not to hedge toward a safe middle (`skills/architect/references/runner-prompt.md:20`).
- **interrogate.** One readonly reviewer per configured model, diversity from models rather than personas (`skills/interrogate/SKILL.md:9`, `:25-36`).
  Each gets the intent paragraph, the rubric and a strict code-quality lens (`:38`).
  The lead puts every finding in Act on, Consider, Noted or Dismissed with the models that raised it, and an Agreement Map (`:40-73`).
  The lead-judgment file names nitpick gravity, hypothetical-versus-actual, and "I would have done it differently" as the main false positives, and says an Act On list over five items is under-filtered (`skills/interrogate/references/lead-judgment.md:18-32`, `:54-58`).
- **how and why.** `how` spawns 2 to 4 explorers and one explainer, or one explainer for simple questions (`skills/how/SKILL.md:13-28`).
  `why` spawns one investigator per available MCP evidence category in one message, each owning one source, then one synthesizer bound by a five-tier confidence framework (`skills/why/SKILL.md:29-84`, `skills/why/references/epistemics.md:5-37`).

### Playbook-level orchestration

- **Autonomous run.** A checkable predicate, a wake mechanism (a watcher subagent on an event with a long heartbeat fallback, or a fixed heartbeat), one change per iteration kept or reverted, a trail row per iteration, and "A plateau is not a stop" (`skills/poteto-mode/playbooks/autonomous-run.md:5-11`).
- **Babysit.** Declare a mode first (`drive`, `background`, `threads-only`, `check`), work only the lowest unmerged PR, one babysitter per stack, never mutate topology, conflicts then threads then CI (`skills/poteto-mode/playbooks/babysit.md:7-11`).
  Classify CI before any retrigger, one fresh build for a flake, and `git merge-base --is-ancestor` before assuming flake (`:19`).
- **Shipping.** Each PR gets a verdict from an agent that did not write it, because "an author checks what it meant to build", and green CI or an approving bot is not a verdict (`skills/poteto-mode/playbooks/shipping.md:5`).
  Land only the contiguous verified run from the bottom (`:6`), re-check verdicts with `git patch-id` across rebases (`:7`), merge bottom-up and read the PR back because a queued merge reports success (`:8`).
- **Autopilot-full.** One cloud owner per independent PR carries build to merge; the root never wrote the code and owns the swarm verdict (`skills/poteto-mode/playbooks/autopilot-full.md:3-16`).
  "Assume the VM dies": push early, start a trail, and record each subagent's id, state and stuck-after runtime in the root's store (`:12`).
  Anything that loosens a gate needs a verifier's proof and the root's countersign, "because the owner is the one who wants green" (`:20`).
  A `/loop 1h` audit re-reads the playbook from trunk each tick, judges agents by side effects, replaces stuck ones at once, and stays quiet when nothing changed for the operator (`:22`).
  A stop reaches every owner as a zero-writes order (`:23`).
- **Autopilot-stack.** Same owners, but the root is the only writer of the chain topology and the operator lands it (`skills/poteto-mode/playbooks/autopilot-stack.md:5-8`).
- **Orchestrate.** A standing coordinator for multi-day programs with "dozens to hundreds of subagents" (`skills/poteto-mode/playbooks/orchestrate.md:3`).
  Three rules carry it: completions are queue events, every spawn carries the standing orders verbatim, and "The brief is the product" (`:7-11`).
  Depth stays at coordinator, track, worker, and "Hard-coded swarm trees were tried and parked as too rigid" (`:19`).
  The brief has GOAL, SCOPE, CONTEXT, ACCEPTANCE, VERIFY, TIMEBOX, FORBIDDEN, REPORT and STANDING, and a missing field is a refuse-to-spawn condition (`:38-57`).
  It collapses to plain work when one agent could finish inside the budget (`:61`), pilots one unit before fan-out (`:63`), lands continuously, and stops spawning at about 70% of the wall-clock budget (`:61`, `:66`).
  Retry by failure mode: cap or OOM gets smaller scope, network drop retries as-is, tool error retries on another model, unknown retries once, and two retries abandon the unit (`:98`).
  A tree-wide stop line goes at the top of the standing orders when further spawning would produce garbage (`:100`).

### Isolation

- One writer per worktree or branch (`skills/poteto-mode/playbooks/orchestrate.md:17`, `skills/principle-separate-before-serializing-shared-state/SKILL.md:9-16`).
- Cloud VMs give each worker its own machine (`docs/guide/02-poteto-mode.md:97-107`); arena candidates get a worktree or `/tmp/arena-<slug>/candidate-<n>/` (`skills/arena/SKILL.md:18`).
- Exactly one stacker mutates a stack's topology and chain rebases run in cloud because "A local rebase at this scale takes the laptop down" (`skills/poteto-mode/playbooks/orchestrate.md:81`).

### Surviving restarts

- The `orch` store uses a PID lock that replaces itself when the holder is dead (`skills/poteto-mode/scripts/orch/store.ts:369-445`) and atomic rename writes (`:337-348`).
- After a Cursor restart, local agents are dead and cloud work is not, so the coordinator re-reads standing orders, recomputes the frontier, and "reattach[es] cloud work by PR and branch rather than agent id" (`skills/poteto-mode/playbooks/orchestrate.md:102`).
- "Never resume an agent to check on it", since a resume restarts an idle agent, and "Transcript mtime is not liveness" (`:96`).
- "Work that exists only on one VM when that VM dies was never done" (`:92`).
- `pause-safely` commits a `wip:` checkpoint and writes a resume note (`skills/poteto-mode/playbooks/pause-safely.md:5-8`); `session-pickup` treats the prior trail as authoritative and refuses to redo it (`skills/poteto-mode/playbooks/session-pickup.md:5-9`).

### The human in the loop

- Reversible work and external actions proceed; irreversible writes always pause; "going to bed" and "run until done" are session overrides (`skills/poteto-mode/SKILL.md:83-87`).
- A fork whose answer is observable is a prototype, not a question, and under a full-autonomy grant "Never give a shorthand token to type back" (`skills/poteto-mode/SKILL.md:20`).
  That is the opposite of our CoS's `go 2` and `drop 2` tokens (ours: `.agents/skills/hzbook-cos/SKILL.md:124`).
- Questions are parked in `gates.md` with options and a default on no answer, and escalation is batched into the status page (`skills/poteto-mode/playbooks/orchestrate.md:30`, `:106-108`).
- `ketchup` is the catch-up contract: open with how many things need the user, under 150 words, and give each action item the decision with a recommendation, then "what happens if the user does not answer" (`skills/ketchup/SKILL.md:21-27`).
- Notifications are the turn ending, plus `/loop` ticks; there is no push channel of its own.

### PR, CI and merge flow

- PRs open ready, never draft, with Conventional Commits titles and a one-minute briefing body under about 40 lines in fixed sections (`skills/poteto-mode/playbooks/opening-a-pr.md:11-30`).
- Opening a PR does not start a babysit; finish the stack first, since per-PR babysits spend checks on commits later waves restart (`:32`).
- Bugbot and security reviews are triaged fix, dismiss or ask against a shared rubric, and from the third pass the agent leans toward dismissing documented patterns except security, auth, billing, data and migrations (`skills/poteto-mode/playbooks/babysit.md:20`).
- `watch-pr` turns PR state into typed verdicts with exit codes per blocker kind: 2 conflicts, 3 review threads, 4 failing checks, 5 timeout, 6 merge gate, 7 status query (`skills/poteto-mode/scripts/watch-pr/types.ts:304-366`).
- Merge prep rebases only when trunk's changes can affect the patch, with explicit rules for lockfiles and changed callers (`skills/poteto-mode/playbooks/autopilot-full.md:19`).

### Model and effort routing

- Per-role lines in `pstack-models.mdc`, with `inherit-parent` or `auto` meaning omit the model (`skills/setup-pstack/SKILL.md:39-66`).
- Panels are lists, one subagent per entry, so the list length is the panel size (`skills/setup-pstack/SKILL.md:31`).
- The spawner picks effort per job: raise one step for the hardest work, lower for routine, fast mode only when trunk is red or a person is blocked, and verification stays on the `swarm workers` model (`skills/poteto-mode/SKILL.md:97`).
- A rejected slug falls back within its family, and a rejected default opens a separate PR to fix the table (`skills/interrogate/SKILL.md:36`).

### Compared with ours

Ours pins every phase's model and effort in `config/<project>/models.json` and the agent never chooses (ours: `.agents/skills/hzbook-coordinator/SKILL.md:15`), which is more structural than pstack's per-spawn judgment.
Ours survives restarts better on T3: `schedule_task` ticks outlive the session and resume it (ours: `docs/plans/hzbook-pstack-takeover.md:129-131`), where pstack's `/loop` lives in the chat and leans on cloud agents for durability.
Ours has a cross-run main lock (`main.mjs`) and an approvals table; pstack has nothing like either, because its owners merge.
pstack's `orch` store (`skills/poteto-mode/scripts/orch/store.ts:17-26`) and ours (`state.mjs`, 411 lines) hold nearly the same tables, and ours is a quarter of its size.

## 3. Memory

### What persists and where

- **Skills in git.** The main durable memory is edits to skills, landed by PR through `reflect` (`skills/reflect/SKILL.md:51-58`) or `automate-me` (`skills/automate-me/SKILL.md:81-83`).
- **The repo itself.** `correct` turns mistake classes into architecture, types, lints or tests, and keeps "a table in the agent instruction file that pairs each rule with what enforces it" (`skills/correct/SKILL.md:28-30`).
- **A tiered rubric file.** `skills/poteto-mode/references/bugbot-triage.md` stores learned dismissal patterns with `Confidence: candidate | recurring | strong`, skip and do-not-skip conditions, and a source (`:15-29`).
  Babysit ends by sweeping its triage decisions into candidate entries in their own PR: "Never keep it only in private memory" (`skills/poteto-mode/playbooks/babysit.md:21`).
- **Decision trails.** One TSV per run, `ts phase decision why evidence result`, append-only, local by default and committed when a reviewer needs it (`skills/show-me-your-work/SKILL.md:11-52`).
- **Program store.** `orchestrate/<project-slug>/` in the agent store: `preferences.md` standing orders pasted verbatim into every spawn, `overview.md` append-only PR and issue log, `units.tsv`, `frontier.json`, `ledger.tsv`, `inbox/`, `gates.md`, `decisions.tsv`, and a derived `status.md` (`skills/poteto-mode/playbooks/orchestrate.md:21-32`).
  "Leave the store intact. It is the postmortem" (`:67`).
- **Transcripts.** `recall`, `session-pickup`, `reflect`, `automate-me`, `eval` and the trail audit all read the workspace's `agent-transcripts/` (`skills/recall/SKILL.md:15`).
  Every one repeats a privacy fence: never glob across `~/.cursor/projects/*/` (`skills/reflect/SKILL.md:15`, `skills/poteto-mode/playbooks/eval.md:22`, `skills/poteto-mode/playbooks/session-pickup.md:5`).
- **Resume notes.** `/tmp/<slug>-resume.md` plus a `wip:` commit (`skills/poteto-mode/playbooks/pause-safely.md:7-8`).
- **Cursor Projects** carry related chats as shared context for a coordinator (`docs/guide/07-overnight.md:94-99`).

### How it is recalled

- `recall` locks a scope (default the last 7 days, the active workspace), fans out cheap subagents over transcript slices ordered by real mtime, runs `why` investigators over the shared record in parallel, then verifies every surfaced PR and branch with `git` and `gh` (`skills/recall/SKILL.md:17-21`).
- Its output tags every thread with exactly one status: `[merged #N]`, `[open PR #N]`, `[in flight <branch>]`, `[verified, uncommitted]`, `[reverted #N]`, `[planned, not started]` (`:29`).
- The standing orders file is recalled by force: pasted into every spawn and resume (`skills/poteto-mode/playbooks/orchestrate.md:25`).

### How it is kept honest and pruned

- Trails are append-only; a wrong row gets a superseding row, never an edit (`skills/show-me-your-work/SKILL.md:52`, `:63`).
- At the end of a run the trail is audited against the transcript, and a different model family reviews trail plus transcript, producing an "Attention" section led by `reviewed by <model>` (`:57-74`).
- A `start` row marks each new run that appends to an existing log, naming the rows it did not write (`:42`).
- `reflect` drops "implementation details that drift: specific SHAs, current file paths, version numbers" (`skills/reflect/references/judgment-reviewer.md:33`, `skills/reflect/references/synthesizer.md:24-34`).
- `correct` drops a rule "once its mistake can't happen" (`skills/correct/SKILL.md:30`).
- `automate-me` update mode mines only history since the skill's last edit and requires a pattern in two or more slices (`skills/automate-me/SKILL.md:23-25`, `:40`, `:87`).
- `why` forces every claim into Direct, Supported, Inferred, Speculative or Unknown, and the presenter must not rewrite that language (`skills/why/references/epistemics.md:5-37`, `skills/why/SKILL.md:88`).
- The router bans fabricated links and demands every claim carry evidence or a label in the same sentence (`skills/poteto-mode/SKILL.md:112-113`).

### Compared with ours

Ours keeps a richer store (priorities, findings, sessions, inbox, threads, rulings) with an inbox cursor and keyed, idempotent appends (ours: `.agents/skills/hzbook-cos/SKILL.md:30-52`, `orchestrate/README.md:51-58`).
pstack's position is that what matters long-term belongs in reviewed, shared files.
Our most important memory, `rulings.md`, lives in `~/.claude/orchestrate/hzbook/` "outside any git checkout" (ours: `.agents/skills/hzbook-cos/SKILL.md:32`), so it has no history and no backup.
That is worth a small fix even though no pstack file prescribes one.

## 4. Self-improvement

### Mechanisms

- **reflect.** Three reviewers on the transcript with different lenses and default models (judgment and divergent on Opus, tooling on Grok), then a synthesizer (`skills/reflect/SKILL.md:23-39`).
  Findings route only to skills the session actually used, or to `tune description:` for a skill that should have fired (`skills/reflect/references/judgment-reviewer.md:18-26`).
  The tooling lens hunts for every moment the user pasted context the agent could have fetched itself (`skills/reflect/references/tooling-reviewer.md:7-17`).
  The synthesizer applies durability, specificity, existing-skill-first, convergence (two or more reviewers), decision-changing, structural-mechanism, skill-was-used and already-covered criteria, and outputs Accepted, Rejected with a reason code, and Backlog (`skills/reflect/references/synthesizer.md:13-56`).
  Anything a lint, script, flag or runtime check would enforce moves to Backlog (`skills/reflect/SKILL.md:41-43`).
  Accepted edits wait for row-by-row human approval, because "Skill changes affect every future agent" (`:45-47`).
- **correct.** Assume "every contributor is an agent that sees only the files it opened, copies the nearest example, and takes the shortest path that compiles" (`skills/correct/SKILL.md:11`).
  A class counts after two occurrences (`:15`), each is fixed at the highest level that works (architecture, types or a lint whose error names the fix, tests, docs last) (`:17-22`), and each new check must fail on a real past mistake (`:26`).
  Exceptions sit on the offending line with a reason, an expiry and a human's approval (`:26`).
- **encode-lessons-in-structure.** "If the fix is structural, only use the structural fix. The instruction is the symptom" (`skills/principle-encode-lessons-in-structure/SKILL.md:11`).
- **Eval.** A skill change is tested blind: no meta words in anything the candidate sees, an organic prompt, one judge on another family scoring by neutral labels, and chain-following graded from which files each candidate actually read (`skills/poteto-mode/playbooks/eval.md:5-25`).
  The guide's reason: "A fix written from one bad session tends to overfit that session, and over many edits the skill drifts" (`docs/guide/09-make-it-yours.md:88`).
- **Fix broken skills in their own PR,** never tangled into feature work (`skills/poteto-mode/SKILL.md:35`, `docs/guide/09-make-it-yours.md:98`).
- **maintain-verification-skill.** A source wave of one read-only subagent per feature, one live pass that drives every feature, and at most one PR of proven corrections (`skills/maintain-verification-skill/SKILL.md:23-37`).
- **automate-me** writes a personal mode skill from history plus a short structured interview (`skills/automate-me/SKILL.md:27-48`).
- **The plan linter.** `check-plan.mjs` enforces the multi-phase plan template, including no long dashes, no curly quotes, no mid-sentence colons, ten numbered live lanes each with a screenshot and a pass predicate, and four perf items (`skills/poteto-mode/scripts/check-plan.mjs:78-80`, `:156-173`), with its own test (`skills/poteto-mode/scripts/check-plan.test.ts`).

### How proposals are verified before adoption

Human approval per row for skill edits, a demonstrated failing check for repo rules, a blind eval for behavior claims, the validator and link check for any authored skill (`skills/poteto-mode/playbooks/authoring-a-skill.md:6-7`), and an explicit Rejected list so the human can overrule the filter.

### Compared with ours

Our lessons pass replays changed scripts on real run data (ours: `orchestrate/cos/templates/lessons-brief.md:17`) and seats `interrogate` on its PR (`:20`), which is stronger than pstack for scripts.
For prose it has no filter: one thread reads the pack, nothing asks it to reject, to check convergence, to find the highest enforcement level, or to strip dated detail.
Our plan's decision 9 named weekly `pstack:reflect` mining and "each recurring pattern becomes a lint, type, or skill ticket" (ours: `docs/plans/hzbook-pstack-takeover.md:49-51`), but neither step exists in the lessons brief.
The rule-to-enforcer table sits in an unscheduled housekeeping list (ours: `docs/plans/hzbook-pstack-takeover.md:175`).

## 5. Engineering practices

### Verification

- `prove-it-works`: check the real thing, and "When verification fails, suspect the observation method before suspecting the system" (`skills/principle-prove-it-works/SKILL.md:9-22`).
- `create-verification-skill` interviews the repo, writes Launch, Doctor, Drive, Evidence, Cleanup and Helpers sections, seeds a feature map with four fixed H2s, and must run its own instructions end to end before handing over (`skills/create-verification-skill/SKILL.md:11-40`).
  Cleanup must never eat the evidence (`:31`, `:40`).
- `blast-radius` ranks each safety fact on a five-step ladder from "You said so" to reproduced in the running app, and proves the one fact the change is safe because of by running code (`skills/blast-radius/SKILL.md:15-37`).
- `benchmark-checklist` asks seven questions, including "Why not double?" and "Did it even happen?" (`skills/benchmark-checklist/SKILL.md:19-27`).
- `tdd` only when the test path is cheap, and "Prefer no new test over a bad test" (`skills/tdd/SKILL.md:9-26`).
- `test-behavior-not-implementation`: delete or rewrite a test that would pass if every imported function returned `undefined`, with a list of the weak assertion shapes (`skills/principle-test-behavior-not-implementation/SKILL.md:9-21`).
- The multi-phase plan template demands ten live lanes per PR, one a regression lane against trunk, plus a dual-sided perf gate (`skills/poteto-mode/playbooks/multi-phase-plan.md:13`, `:100-118`).

### Review

- The code-quality lens asks every reviewer for "code judo" restructurings, refuses PRs that push a file past 1,000 lines, treats ad-hoc branches in shared flows as design problems, and makes those presumptive blockers (`skills/interrogate/references/code-quality-review.md:21-43`).
- The architect red flags are written for agent contributors: shallow modules, information leakage, temporal decomposition, pass-through methods, split ownership, two ways to do one task, importable internals, hand-synced lists (`skills/architect/references/design-red-flags.md:5-57`).
- `no-comments` spawns Comment Sicko and rejects its overreach in the parent (`skills/no-comments/SKILL.md:19-24`).

### Structure versus prose

Enforced by structure: the plan linter, the trail logger's cell cleaning against spreadsheet formula injection (`skills/show-me-your-work/scripts/log.sh:26-39`), the `orch` store's typed verdicts and refusals (`skills/poteto-mode/scripts/orch/store.ts:287-295`), the watcher's typed exit codes, the worktree audit (`skills/poteto-mode/scripts/worktree-audit.sh:1-13`), a frozen-lockfile bootstrap keyed on a hash of `package.json` and `bun.lock` (`skills/poteto-mode/scripts/bootstrap.ts:17-33`), file-glob skill attachment, and invocation gating.
The scripts carry 2,159 lines of tests, including type-level tests (`skills/poteto-mode/scripts/watch-pr/types.compile.ts`).
Everything else is prose: principles, playbooks, reply style.
The router's semi-structural audit is copying playbook steps verbatim into the todo list, with `skip: <reason>` for any step not done (`skills/poteto-mode/SKILL.md:123`).

### Compared with ours

Ours enforces more of the run in scripts than pstack does (state machine refusals, merge gate, main lock, approvals, cleanup by recorded names).
Ours checks less of the code: the `review` lane is correctness only (ours: `orchestrate/coordinator/templates/lanes/review.md:1-2`), `review-gpt` is tests only (`orchestrate/coordinator/templates/lanes/review-gpt.md:1-2`), and the in-scope rule admits only acceptance breaks and introduced defects (`orchestrate/coordinator/templates/checker-brief.md:31`).
No lane or builder rule mentions file size, branching growth, duplication, abstraction depth or type discipline (ours: `orchestrate/coordinator/builder-rules.md:1-20`).
Our `review-gpt` lane's revert-and-rerun check (`review-gpt.md:1`) is stronger than pstack's static undefined-return heuristic, and the two combine well.

## 6. Simplicity

### What pstack deliberately leaves out

- Planning skills: "i don't believe in planning. the best spec is code" (`README.md:252-254`).
- A memory store, a daemon and a scheduler: `orch` "never spawns, waits, or wakes anything" (`skills/poteto-mode/playbooks/orchestrate.md:15`), and waking is Cursor's `/loop`.
- Hard-coded swarm trees (`:19`), verifier agents whose job is rerunning one command, which it calls "ceremony, not verification" (`:88`), and per-PR babysits (`skills/poteto-mode/playbooks/opening-a-pr.md:32`).
- Implicit triggers: 53 of 54 skills only load when typed or routed.
- Tools it can borrow: `deslop`, `control-ui`, `control-cli`, `/loop`, `/create-skill` (`README.md:242-250`, `skills/poteto-help/SKILL.md:107-111`).
- Graphite: "Never require `gt`" (`skills/poteto-mode/playbooks/babysit.md:7`).

### How ceremony scales down

- Orchestrate collapses to direct work when one agent could finish (`skills/poteto-mode/playbooks/orchestrate.md:61`), runs the pilot as a normal unit for clone-like units (`:63`), and sizes the brief to the unit: "A 4KB scaffold around a two-line edit costs more to write and obey than the edit" (`:53`).
- The plan playbook stops at once for a one- or two-file change (`skills/poteto-mode/playbooks/multi-phase-plan.md:5`).
- `how` takes the simple single-agent path "When in doubt" (`skills/how/SKILL.md:20`).
- `figure-it-out` says a second arena over a settled design is over-engineering (`skills/figure-it-out/SKILL.md:30`).
- Authoring rule: "When in doubt, delete. Keep only prose that changes a decision. Tell it to do the thing and skip the reason" (`skills/poteto-mode/playbooks/authoring-a-skill.md:10`).
- The guide's advice to adopters: "Start smaller than you think ... add a skill or a check when the same failure shows up twice" (`docs/guide/09-make-it-yours.md:5`).

### Size of moving parts

| Piece | Lines |
|---|---|
| Router `poteto-mode/SKILL.md` | 149 (3,161 words) |
| 23 playbooks | 618 |
| 24 principles | 455 |
| Other skill prose and references | about 3,500 |
| `orch` store and CLI | about 2,270 |
| `watch-pr` | about 2,360 |
| `check-plan.mjs`, `worktree-audit.sh`, `log.sh`, `bootstrap.ts` | 435 |
| Script tests | 2,159 |
| Guide | 1,104 |
| Benny pack | 1,612 |

pstack is light in prose per job and heavy in typed, tested scripts.
The opposite of prose-light is visible in ours: the generated coordinator skill is 277 lines and 5,892 words with six dated incidents inline (ours: `.agents/skills/hzbook-coordinator/SKILL.md:179`, `:202`), though its own line 12 says the reasons live in the plan.
The chief of staff is 3,546 words.
Both are read on every cold start, restart and tick.

## 7. Ideas worth stealing, ranked

### 1. A code-quality and agent-era design lens in the review lanes

- **What.** Give the `review` checker pstack's code-quality lens and architect red flags, and give `review-gpt` the weak-assertion list.
- **Where in pstack.** `skills/interrogate/references/code-quality-review.md:21-43`, `skills/architect/references/design-red-flags.md:5-57`, `skills/principle-test-behavior-not-implementation/SKILL.md:9-21`.
- **Why for us.** Our lanes judge correctness and tests only (ours: `orchestrate/coordinator/templates/lanes/review.md:1-2`, `review-gpt.md:1-2`), so nothing stops a PR that works but grows spaghetti, crosses 1,000 lines, or adds a second way to do a task, which is exactly what the next agent copies.
  Bryce's stated priorities are simplicity and code quality, and this is the one place pstack checks something we do not.
- **T3 mapping.** No new primitive: copy the two references beside the lane templates, have `review.md` tell the checker to apply them, and treat only the approval-bar items (`code-quality-review.md:43`) as in-scope findings, the rest as follow-ups.
  Checkers stay `delegate_task` children in worktrees.
  A follow-up ticket in each product repo can turn the weak-assertion list into a lint, per `/correct`.

### 2. A rule-to-enforcer table and the structure-first ladder for every lesson

- **What.** Every builder and coordinator rule gets a row naming what enforces it, and every lesson is placed at the highest level that works, with proof the check fails on a real past case.
- **Where in pstack.** `skills/correct/SKILL.md:11-30`, `skills/principle-encode-lessons-in-structure/SKILL.md:9-11`, `skills/reflect/SKILL.md:41-43`, `docs/guide/09-make-it-yours.md:35-42`.
- **Why for us.** Our 13 builder rules are prose (ours: `orchestrate/coordinator/builder-rules.md:1-20`), the table is an unscheduled housekeeping item (ours: `docs/plans/hzbook-pstack-takeover.md:175`), and the lessons brief never asks which level should hold a lesson (ours: `orchestrate/cos/templates/lessons-brief.md:14-20`).
  A rule with no enforcer that gets broken again is, in pstack's words, "a repeat" to fix at a higher level (`skills/correct/SKILL.md:30`).
- **T3 mapping.** A table in `orchestrate/coordinator/builder-rules.md` (or an `enforcement.md` beside it), a test that fails when a rule has no row, and one lessons-brief step that applies the ladder.
  Our `replay.sh` already is the "fails on a real past mistake" proof for script checks.

### 3. Put the generated skills on a word budget and strip drift detail

- **What.** Cap each generated SKILL.md's size in the build, reject dates and incident stories in skill sections, and move reasons to the plan docs.
- **Where in pstack.** `skills/poteto-mode/playbooks/authoring-a-skill.md:10`, `skills/reflect/references/synthesizer.md:24-34`, `skills/principle-subtract-before-you-add/SKILL.md:13-18`.
- **Why for us.** 5,892 words for the coordinator and 3,546 for the chief of staff, re-read on every tick and restart, against 2,692 for pstack's whole Orchestrate playbook; dated parentheticals like `.agents/skills/hzbook-coordinator/SKILL.md:179` belong in `docs/plans/`.
  Smaller skills are cheaper per tick and easier for a model to follow.
- **T3 mapping.** None needed: `orchestrate/build.mjs` prints word counts, fails above a committed budget that a PR may raise only with a stated reason, and fails on `20\d\d-\d\d-\d\d` in skill sections.
  The next lessons pass gets one subtraction goal.

### 4. Reflect's acceptance filter inside the lessons pass

- **What.** Two miners with different lenses and model families, then a synthesis that outputs Accepted, Rejected with a reason code, and Backlog, using durability, convergence, decision-changing, structural and already-covered tests.
- **Where in pstack.** `skills/reflect/SKILL.md:23-47`, `skills/reflect/references/synthesizer.md:13-56`, `skills/reflect/references/divergent-reviewer.md:1-36`.
- **Why for us.** One thread folds the pack alone (ours: `orchestrate/cos/templates/lessons-brief.md:1-20`), with no rejection step, so lessons only accrete; our plan already intended reflect mining (ours: `docs/plans/hzbook-pstack-takeover.md:49-51`).
  A Rejected table in the PR gives Bryce the same "trust mechanism" interrogate's Dismissed list gives (`skills/interrogate/references/lead-judgment.md:58`).
- **T3 mapping.** The lessons thread starts two `delegate_task` children (an Opus target and the `review-gpt` Codex target) over the pack, then synthesizes; Backlog rows become `needs-triage` issues in agent-configs.
  Bryce's PR review stays the approval gate.

### 5. Lint agent-authored artifacts the way `check-plan.mjs` lints plans

- **What.** `state.mjs verdict` reads the verdict file and refuses one without a verdict line, a head equal to the round's head, or evidence on each in-scope item; a missing or malformed verdict is respawned once, then recorded as `BLOCKED`, never a pass.
- **Where in pstack.** `skills/poteto-mode/scripts/check-plan.mjs:5-205`, `skills/swarm/SKILL.md:40`, `skills/poteto-mode/playbooks/orchestrate.md:57`.
- **Why for us.** The verdict shape is defined (ours: `orchestrate/coordinator/templates/checker-brief.md:44-55`) but nothing parses it, and "state.mjs verdict refusing a verdict that does not name the head it judged" is already a listed candidate (ours: `docs/plans/hzbook-pstack-takeover.md:175`).
  This moves a prose rule into the one script that already refuses illegal moves.
- **T3 mapping.** Add a `HEAD:` line to the checker brief, a parser in `orchestrate/coordinator/bin/state.mjs`, and use the existing `--attempt 2` respawn.

### 6. End-of-run trail audit with a cross-family Attention list

- **What.** At Finish, a different model reads the run's trail and the coordinator thread and flags weak evidence, skipped verification and risky calls; the finished report leads with that list.
- **Where in pstack.** `skills/show-me-your-work/SKILL.md:57-74`, `skills/poteto-mode/playbooks/orchestrate.md:67`.
- **Why for us.** Our Finish reports without auditing `decisions.tsv` (ours: `.agents/skills/hzbook-coordinator/SKILL.md:257-266`), and run results record a CoS brief and two coordinators reporting state that was wrong (ours: `docs/plans/hzbook-run-results.md:184-185`, `:238`).
  It also feeds the lessons pack judgments, not only facts.
- **T3 mapping.** One `delegate_task` on the `review-gpt` target reading `decisions.tsv`, `moves.tsv`, `gates.md` and the thread through `t3_thread_read`, writing `attention.md` in the run folder; `state.mjs finish` links it in the `finished` inbox row and `lessons.mjs` packs it.
  Add pstack's `start` row convention to `decisions.tsv` at each Restart (`skills/show-me-your-work/SKILL.md:42`).

### 7. A hold file that stops every writer

- **What.** One file that every merge, launch and frontier step refuses on, with a zero-writes line sent to live builders.
- **Where in pstack.** `skills/poteto-mode/playbooks/autopilot-full.md:23`, `skills/poteto-mode/playbooks/orchestrate.md:100`, `skills/poteto-mode/playbooks/multi-phase-plan.md:43`.
- **Why for us.** `away.md` is our only mode file (ours: `.agents/skills/hzbook-cos/SKILL.md:143-149`), a `hold.md` twin is deferred (ours: `docs/plans/hzbook-pstack-takeover.md:174`), and several coordinators share odin, main and one usage limit.
- **T3 mapping.** The CoS writes `hold.md` on Bryce's word; `main.mjs claim`, `brief.mjs` and `state.mjs frontier` refuse while it exists; each coordinator's tick sends live builders one `t3_thread_send` line and lets checkers finish.

### 8. Say what happens on silence for every ask

- **What.** Each ask names the decision, the recommendation and why, and what happens if Bryce does not answer.
- **Where in pstack.** `skills/ketchup/SKILL.md:17`, `:27`, `skills/poteto-mode/SKILL.md:20`.
- **Why for us.** Gates carry defaults (ours: `.agents/skills/hzbook-coordinator/SKILL.md:248`), but CoS replies and queue items do not say what silence means (ours: `.agents/skills/hzbook-cos/SKILL.md:64`, `:122-125`).
- **T3 mapping.** A CoS reply rule and the default printed on each `inbox.mjs open` line.

### 9. A confidence-tiered pattern file for review noise

- **What.** A reviewed file of recurring false positives from review bots and checkers, each `candidate`, `recurring` or `strong`, with skip and do-not-skip conditions and a source, promoted only by repeat evidence.
- **Where in pstack.** `skills/poteto-mode/references/bugbot-triage.md:9-29`, `:75-86`, `skills/poteto-mode/playbooks/babysit.md:21`.
- **Why for us.** Snapcaster's profile lists review bots whose threads must be resolved (ours: `orchestrate/README.md:19`), and `findings.md` has no tiers or promotion rule.
- **T3 mapping.** A file in agent-configs read by the coordinator when it triages follow-ups and bot threads; the lessons pass promotes entries.

### 10. Verification-map upkeep on a trigger

- **What.** Propose `maintain-verification-skill` when the app has drifted from the map.
- **Where in pstack.** `skills/maintain-verification-skill/SKILL.md:9-39`.
- **Why for us.** The map was maintained once (ours: `docs/plans/hzbook-pstack-takeover.md:111`), and BLOCKED live lanes signal gaps (`:168`, `:189-191`).
- **T3 mapping.** A CoS "what next" rule: maintain pass due after a set number of UI merges since the last maintain PR or after any BLOCKED live verdict, run as a `delegate_task` in the product project.

### 11. Benny's shape for outside intake

- **What.** Two stages with a trusted marker between them, fail closed on missing config, repro twice through the real UI, a media reviewer, a bounded fix gate, draft PR only.
- **Where in pstack.** `automations/benny/FOR_AGENTS.md:3-36`, `automations/benny/skills/reproduce-and-fix-issues/SKILL.md:13-32`, `:56-78`, `:163-183`, `:226-238`.
- **Why for us.** Our plan already names Benny as the shape for Sentry and client email intake and probed a T3 webhook relay (ours: `docs/plans/hzbook-pstack-takeover.md:174-176`).
- **T3 mapping.** A `schedule_task` webhook into the CoS thread, a triage child task that appends one marker row to the inbox, and a repro child task in a worktree driving `verify-hzbook`.

### 12. A blind eval for template changes that claim to change verdicts

- **What.** Replay one past round with the old and the new checker brief on the same head, judged blind.
- **Where in pstack.** `skills/poteto-mode/playbooks/eval.md:5-25`, `docs/guide/09-make-it-yours.md:76-92`.
- **Why for us.** `replay.sh` proves scripts, but prose changes to briefs and lanes ship on review alone.
- **T3 mapping.** Three `delegate_task` children per eval, only for lane and brief template changes.

### Considered and rejected

- The poteto-mode router and its 23 playbooks: our coordinator is one specialized workflow, and a general router would add tokens to every tick.
- Per-spawn effort and model judgment (`skills/poteto-mode/SKILL.md:97`): our pinned `models.json` is more structural.
- Ten live lanes plus a perf lane per PR (`skills/poteto-mode/playbooks/multi-phase-plan.md:100-118`): too slow and costly for 3-to-5-ticket runs; our one live lane with a base comparison covers the regression case.
- The 2,360-line `watch-pr`: `watch-run.sh` plus `merge-ready.mjs` already cover it in a fraction of the code.
- Porting the `orch` store: it converged with `state.mjs`, which is a quarter of its size.
- Opening PRs ready instead of draft (`skills/poteto-mode/playbooks/opening-a-pr.md:30`): conflicts with our CI-cost decision 4.
- Owner merges in Autopilot-full: Bryce approves every merge.
- A fresh subagent for every follow-up (`skills/poteto-mode/SKILL.md:101`): already rejected; run 7 saved 1h20 by reusing the builder.
- Sub-coordinators and rolling windows of dozens of agents: one machine and one usage limit cap us well below that.
- `recall` from transcripts for the chief of staff: already rejected; the store and `brief.mjs` are the memory.
- Lead-judgment filtering of checker findings by the coordinator: weakens checker independence, and pstack's own autopilot sends every proven finding to the owner (`skills/poteto-mode/playbooks/autopilot-full.md:16`); a cross-lane agreement column on the evidence page is the cheap part worth keeping.
- Comment Sicko's no-comments stance: Bryce wants useful comments, and `config/pstack/workflow.md:64` already overrides it.
- Cloud agents by default: T3 runs worktrees on odin, not VMs.
- Origin and Graphite forge abstractions: GitHub only.
- `/loop` ticks: `schedule_task` survives restarts and is strictly better on T3.
- Mandatory arena for every feature implementation (`skills/poteto-mode/playbooks/feature.md:12`): doubles builder cost; architect for deep tickets is enough.
- The multi-phase plan template: tickets come from to-spec and to-tickets; only its linter idea is worth taking.
- `make-bot-ui`, the session hook, and shorthand-free asks under full autonomy: the first two were already rejected, and Bryce chose the `go` queue deliberately.
