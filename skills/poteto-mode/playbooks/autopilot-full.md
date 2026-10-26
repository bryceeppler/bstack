### Autopilot-full

**You own the verdicts and the run branch.**
**One owner carries each issue to a verified commit, you land each commit on the run branch, and the run ships as one PR to trunk.**

CI bills a run for every head of a ready PR and none for a branch push, so owners open no PRs and the run's one PR is its first CI.
A verdict covers one patch and green CI covers one head.
The patch-id rule in `playbooks/shipping.md` can carry a lane's result.

1. **The operator's gates come first.**
   The grant covers only the run's issues, so an issue the operator names as theirs stops at landing-ready.
   A request to state the plan is not a go.
2. **Create the run branch.**
   Create `run/<cluster-slug>` from current trunk and push it before any owner starts.
   You are its only writer.
   A run holds only the cluster it was given.
3. **Spawn one owner per issue, and keep its work where a replacement can find it.**
   GitHub CLI (`gh`) is the forge.
   Never require `gt`.
   Each owner is a `t3_thread_launch` thread on its own branch with a worktree `workspaceStrategy` off the run branch, its brief opening with the text of `../references/poteto-agent.md`, its placeholder replaced by the absolute path of poteto-mode's `SKILL.md`.
   Its `modelSelection` comes, as configured, from the `owner small`, `owner standard` or `owner deep` role matching the issue's `complexity:*` label, and with no such line or label the owner runs on this thread's model.
   Commit first, because uncommitted edits do not reach a new worktree.
   Owners run in parallel, never stacked.
   Each builds, pushes only its own branch, opens no PR, and proves the change on the real artifact.

   The code is ready only after the slop-strip (the **deslop** skill (`/deslop`)) and the `/no-comments` pass, so the full swarm runs on finished code.
   Then the owner squashes the issue to one commit, rebases it onto the run branch tip, runs the repo's checks for the touched paths, and reports the code-ready head.
   Fix rounds amend that commit and report each new head.
   Once self-proof is done and every finding is fixed, it reports landing-ready.

   Assume the thread dies.
   Soon after starting, push and start a decision trail per the **show-me-your-work** skill in the root's store at `~/.local/state/pstack/orchestrate/<project-slug>/trails/`, outside any worktree, then push after every unit worth keeping.
   Whoever spawns a subagent records its `delegate_task` taskId or thread id, state, and a stuck-after runtime from past runs of its kind in that store, so the root can probe it if the parent dies.
   Force-push only your own branch, with `--force-with-lease` pinned to the SHA you last pushed or took over, and on any push you did not make, stop and report to the root.
4. **Swarm-verify once.**
   A full swarm runs once, at the code-ready head.
   Another full swarm runs only for new behavior, a redesign, or a large new diff.
   A rebase, a merge-conflict resolution, or a minor fix gets a single verifier at the new head.
   Fan out independent verifiers at the code-ready SHA per the **swarm** skill, the diff audit on this thread's model (omit `target`) and the live lane on the `swarm workers` model, or on this thread's model when the owner is of the `swarm workers` model's family, so no lane is the issue's author and its live proof never comes from the owner's model family.
   They re-run the gates, prove the load-bearing behavior live on the real surface per the Non-negotiables, and audit the diff.
   The verdict is not clean without the live lane, or before you audit the landing-ready report's receipts, because no lane trusts a claim it has not checked.

   Send every proven finding, whatever a lane labeled it, to the owner in one fix-forward, with a red test across every site with the same defect.
   A defect trunk shows without the issue's commit is recorded against trunk and does not gate the issue, but one the commit copies or newly reaches is the commit's own.
   Never push a fix yourself, because each branch has one writer.
   Replace a stuck owner instead.
5. **Land each verified issue yourself, one at a time.**
   Fast-forward the run branch to the owner's landing-ready commit and push without force.
   When the tip has moved, the owner rebases again, the patch-id rule decides whether the verdict survives, and a conflict resolution gets a single verifier per step 4.
   An issue that cannot be proven stays off the run branch and open, with the exact reason commented on it.
6. **Prove the run together, then open its one PR.**
   Once every issue has landed or been left open, merge current trunk into the run branch if it moved, run every check the repo's `AGENTS.md` names on its tip, and have one verifier that wrote none of it prove the issues together on that head.
   Then open one PR to trunk, with a `Closes #<n>` line and its verdict for each landed issue and a line for each issue left open.
   Open it as a draft only while a proof the run cannot produce itself is outstanding, and mark it ready once that proof passes.
   You babysit it per `playbooks/babysit.md`.
   After it opens, push only fixes or a trunk merge step 7 calls for, and each new head needs a single verifier and green CI before it clears.
   With no issue landed, open no PR and report the run blocked.
7. **Merge only what you verified, tested on the trunk it lands on.**
   Green CI alone never authorizes a merge.
   Right before merging, fetch trunk and ask whether its changes can affect the run, because merging trunk in for every move never ends.
   Merge trunk in when it conflicts, when the forge requires an up-to-date branch, or when trunk changed something the run calls or depends on.
   Otherwise merge.
   Merge with `gh pr merge <pr> --merge`, not a squash, so each issue stays one revertable commit on trunk.
   Call `unwatch_pull_request` before you report.
8. **Run the root layer.**
   Anything that loosens a gate, such as a raised budget or an allowlist entry, needs a verifier's proof and then your fresh countersign, because the owner is the one who wants green.
   Under a grant that covers approvals, that countersign is the approval.
   A disabled or soft-failed check always comes out, because it stops guarding every case.
   Never give or bypass an approval the forge enforces, because no countersign covers it.

   On the operator's go, arm `schedule_task` with `{"type":"interval","everyMs":3600000}`, bound to this root thread, with a prompt that runs this audit, until no delegated work is left, because long runs drift and agents stall silently.
   Each tick re-reads this playbook from the installed copy at `<poteto-mode dir>/playbooks/autopilot-full.md` (`npx skills update -g` refreshes it) and fixes drift, such as an unreported head or an unrecorded agent, by having its owner record it.
   It probes every agent, down to the leaf lanes (`t3_thread_list` with `includeSubagents: true`, `t3_thread_read`, and each owner's `task_status` on its own children), and judges each by its side effects, because status text and summaries can hide a stuck child.
   An agent is stuck when it errors, cannot start turns, or shows nothing new past its stuck-after runtime, and so is an owner that has neither pushed nor written a trail row by the first tick.
   One waiting on you or the operator is not stuck, so answer it.
   Replace a stuck agent at once, without waiting for its stop to land.
   A tick that changed something for the operator ends by catching them up per the **ketchup** skill, and one that changed nothing stays quiet.
   End the cadence with `delete_scheduled_task` once no delegated work is left.
9. **Stand down at once on the operator's stop.**
   A hold reaches every owner as a zero-writes order, and the root pauses the audit schedule with `update_scheduled_task` (`enabled: false`).
   Each owner reports where it stands and keeps its brief until the operator releases it, and the release re-enables the schedule.

**Reply:** catch the operator up per the **ketchup** skill, covering each issue's state and verdict, what landed on the run branch, the run PR's state, countersigns and why, and open operator gates, with links to the run PR and the trails.
