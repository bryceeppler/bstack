# T3 Code orchestration deep dive, for Bryce's CoS and coordinator skills

Target: `pingdotgg/t3code` at `339179f5` (2026-10-15), read-only, about 550 commits of history (2026-10-08 to 2026-10-15).
Our side: `/home/bryce/git/agent-configs/orchestrate/` (abbreviated `OR/`) and the plan docs under `docs/plans/`.

Path keys used below:
`S` = `apps/server/src`; `O2` = `S/orchestration-v2`; `TK` = `S/mcp/toolkits`; `C` = `packages/contracts/src`.
`ORC` = `O2/Orchestrator.ts`; `OMS` = `S/mcp/OrchestratorMcpService.ts`; `TMS` = `O2/ThreadManagementService.ts`; `PSM` = `O2/ProviderSessionManager.ts`.
`TSS` = `O2/ThreadSettlementService.ts`; `CLA` = `O2/Adapters/ClaudeAdapterV2.ts`; `PBW` = `packages/shared/src/orchestrationV2PendingBackgroundWork.ts`.
`ST` = `S/scheduledTasks/ScheduledTaskService.ts`; `PRW` = `O2/PullRequestWatchReactor.ts`; `prw` = `O2/pullRequestWatch.ts`.

## 0. Read this first

Odin runs nightly `0.0.46-nightly.20261014.3105` (`~/.t3/runtime/service-state.json`), which is commit `3417bc38`, 63 commits behind HEAD.
Not in odin's build: the child-question wake (`fdacb3a3`, `924fb0c4`, `c814e51a`), stale-Waiting fix (`519d64f6`), restart delivery fix (`22af947e`), keep-PR-threads auto-settle (`bf8ffe81`), settled-worktree cleanup (`21bedfb1`), branch delete (`339179f5`).
In odin's build: `delegate_task isolation` (`25629a76`), restart continuation on by default (`b9ad3daf`), idle-pin reset by activity (`e4ef8d36`), the PR-watch rerun fix (`a4180751`), PR guides (`18656a34`).
Odin's settings (`~/.t3/userdata/settings.json`): `autoResumeLimitedThreads: true`, `sidebarAutoSettleOnMerge: false`, `sidebarAutoSettleAfterDays: null`.

Headline answers:
- `watch_pull_request` still never reports a merge: a merged PR ends the watch silently (`PRW:524-530`), a closed one wakes (`PRW:396-407`).
- It still ignores comments by the viewer account, which is Bryce's own GitHub login (`prw:80-91`).
- Nothing in T3 needs a live session to wake a thread: messages, ticks, PR-watch wakes and child completions all go through `message.dispatch`, which reopens and resumes the same native conversation (`O2/ProviderTurnStartService.ts:531-549`, `:672-730`).
- So the Monitor keep-alive exists only because our watcher runs inside the session; T3 itself does not require it.
- A PR watch counts as a "monitor" hold for phone alerts and auto-settle (`PBW:289-302`, `PBW:73-88`), without pinning the session (`CLA:9116-9141` probes only provider-side work).
- `delegate_task` children never produce phone pushes (`packages/shared/src/agentAwareness.ts:62`), and a follow-up `t3_thread_send` to a finished child creates a fresh task whose completion wakes the parent (`TK/orchestrator/tools.ts:238`).
- Two bugs in our skills: the CoS reads run status `waiting` as "stopped on a question" (it means "turn over, background work pending"), and `clientRequestId` dedupe does not survive a session restart.

## 1. The orchestration MCP tool surface (as implemented)

Endpoint `http://127.0.0.1:<port>/mcp`, server key `t3-code` (`docs/orchestration-v2/orchestrator-mcp-server.md:31-38`).
Each provider session gets a bearer credential scoped to environment, thread, provider instance and session (`S/mcp/McpSessionRegistry.ts:124-150`).
Capabilities granted: `orchestration`, `worktree`, `pull-requests`, plus `preview` when browser tools are on (`McpSessionRegistry.ts:138-143`).
Credential liveness is 24 hours since the last MCP call; there is no maximum lifetime (`McpSessionRegistry.ts:82`, `:115-122`).
Outside agents (Claude Code CLI, Codex, ChatGPT) can sign in over OAuth and call the same tools with no calling thread (`S/auth/McpOAuth.ts:555-597`; `docs/user/outside-agents.md`).

### 1.1 Cross-cutting rules

- Idempotency: `clientRequestId` derives command, thread and message IDs under `scope.requestNamespace` (`OMS:604-680`).
- For a thread caller that namespace is the provider session ID, a fresh random UUID per session (`McpSessionRegistry.ts:127`, `:133`).
- Consequence: a retry with the same `clientRequestId` after an idle release, crash or T3 restart is new work, not a replay.
- For an OAuth outside client the namespace is `client:<sessionId>`, stable for its 30-day sign-in (`McpOAuth.ts:574`).
- Calls without `clientRequestId` get a random key and always create new work (`OMS:1325-1328`).
- Privilege ceiling: a tool that changes another thread needs the caller's live run, and the target's runtime and interaction modes may not be broader than the caller's (`OMS:1098-1110`; doc `:483-487`).
- This is the `interaction_mode_escalation_denied` a plan-mode thread hit when messaging the CoS (`hzbook-run-results.md:294`).
- Expected failures come back as typed `OrchestratorMcpFailure` codes, not exceptions (doc `:497-514`).
- Injected agent instructions: Claude gets `T3_CODE_ORCHESTRATION_INSTRUCTIONS` appended to the system prompt (`CLA:1162-1168`; text at `packages/provider-core/src/server/orchestrationInstructions.ts:3-37`).
- The runtime block tells every agent to call `watch_pull_request` and end the turn rather than "poll or run your own watcher" (`packages/provider-core/src/server/runtimeInstructions.ts:2`); our builder rule 7 overrides this on purpose (`OR/coordinator/builder-rules.md:13`).
- Claude's MCP tool timeout is 65 minutes (`CLA:1210`).

### 1.2 Delegation and threads (`TK/orchestrator/tools.ts`, handlers in `OMS`)

| Tool | Def | Semantics that matter |
|---|---|---|
| `orchestrator_capabilities` | `:53-64` | Live provider and model catalog; `features` is hard-coded (`OMS:1966-1975`). |
| `delegate_task` | `:66-77` | Needs an active run owned by this session (`OMS:1980-1991`). Creates a child thread with lineage `subagent`, prompt only, no parent history. |
| | | `isolation: "worktree"` resolves the parent checkout's `HEAD` and creates a worktree at that commit, `startFromOrigin: false` (`OMS:2020-2031`); uncommitted edits are not copied (`C/orchestratorMcp.ts:177-182`). |
| | | `mode: "async"` sets `completionWake: "always"`: every terminal child turn wakes the parent, steered into a live turn where supported, else queued (`OMS:2054-2057`). |
| | | `mode: "wait"` defaults to 10 minutes, max 60 (`OMS:102-103`); a timeout upgrades the task to `always` so a later result still wakes (`OMS:2105-2130`). |
| `task_status` | `:79-91` | Reads only tasks of this parent thread; `workState`, `hasPendingChildRuns`, `latestTerminal*`; reading a terminal result acknowledges its delivery. |
| `task_cancel` | `:93-103` | Same as a user Stop on the child: interrupts, holds queued turns, ends PR watches, stops grandchildren, disposes the parent delivery. |
| `create_threads` | `:180-191` | 1-20 top-level threads sharing the caller's checkout; `clientRequestId` gives stable thread IDs. |
| `t3_thread_launch` | `TK/project/tools.ts:104-150` | One top-level thread with `workspaceStrategy` (`worktree` with `baseRef`, `branch`, `startFromOrigin`; `existing_worktree`; `root`). No retry key. Message up to 120k chars. |
| `t3_thread_list` | `:193-205` | Per project, filters `statuses` (max 10), title, `settled`, `snoozed`; items carry `parentThreadId`, `relationshipToParent`, `linkedPullRequest` (`C/orchestratorMcp.ts:306-345`). |
| `t3_thread_read` | `:207-221` | `messages` or `activity` view, `afterPosition` paging, `itemId`/`textOffset` for long items; detail includes `pendingRequestCount` (`C/orchestratorMcp.ts:388`). |
| `t3_thread_update` | `:223-234` | rename, regenerate title, link or unlink a PR; `clientRequestId` replays the receipt. |
| `t3_thread_send` | `:236-247` | Modes in 1.3. Archived targets refused (`TMS:797-801`); settled targets accepted and un-settled (`ORC:4672-4691`). |
| `t3_thread_wait` | `:249-261` | Waits on run status only; default 10, max 60 minutes; never acknowledges a delegated result. |
| `t3_thread_interrupt` | `:263-273` | Interrupts the newest interruptible run; `no_active_run` otherwise. |

Messages an agent sends carry `createdBy: "agent"`, `creationSource: "mcp"` and `senderThreadId` (`OMS:2604-2648`; `C/orchestrationV2.ts:1209`).
The web timeline renders the sender as a link (`apps/web/src/components/chat/MessagesTimeline.tsx:2469-2471`); whether the receiving model sees the sender is unconfirmed.

### 1.3 `t3_thread_send` modes and the queue (`TMS:794-875`, `TK/thread/tools.ts:64-128`)

- `auto`: steer a steerable active turn, else `start_immediately` (`TMS:818-823`).
- `queue`: `queue_after_active`, which queues only behind a blocking run (preparing, starting, running, waiting) and otherwise starts at once (`ORC:536-543`, `ORC:4958-4980`).
- `steer` and `restart` require a steerable active turn; `restart` is interrupt-and-restart (`TMS:807-817`).
- A follow-up to a completed app-owned child creates a fresh task in that child thread, returns `taskId`, and its completion notifies the parent (`TK/orchestrator/tools.ts:238`; `C/orchestratorMcp.ts:455`).
- Provider-native subagent threads refuse messages (`ORC:10915-10929`); app-owned `delegate_task` children accept them, and the web composer is read-only only for provider-native ones (`apps/web/src/components/ChatView.tsx:2144`).
- The user doc still says agent-started subagent threads "can't take messages" (`docs/user/thread-sidebar.md:221`), which matches only the provider-native case.
- Queue tools: `t3_queue_list` (100 per page), `t3_queue_read` (16k chars), `t3_queue_edit`, `t3_queue_cancel`, `t3_queue_reorder`, `t3_queue_promote_to_steer` (`TK/thread/tools.ts:80-128`).
- No MCP tool dispatches `queue.resume`, so an agent cannot release a queue held by Stop or a restart (`ORC:10983-11030`).

### 1.4 Pending requests, organize, config, fork

- `t3_pending_request_list/read/respond` cover `user_input` questions only, never approvals (`TK/thread/tools.ts:151-176`; `TK/thread/handlers.ts:203-212`).
- Any thread in the environment can be answered, within the mode ceiling (`S/mcp/threadAccess.ts:103-131`).
- A `delegate_task` child's question now queues a wake to the parent (`O2/DelegatedTaskQuestionReactor.ts:45-54`, `:108-162`; `fdacb3a3`, not on odin).
- `t3_thread_organize`: pin, snooze, settle, archive, mark unread and their reverses (`TK/thread/tools.ts:31-62`); settling yourself returns `settlesWhenTurnEnds` and lands only if the run completes (`TMS:980-1011`, wait up to 24 h in memory, `TMS:547`).
- There is no MCP action for per-thread "Auto-settle behavior: Disabled"; the command exists (`ORC:2575`) but only the UI sends it.
- `t3_thread_configuration/configure` read and set model selection, never permission modes (`:178-200`).
- `t3_thread_fork`, `t3_thread_merge_back`, `t3_thread_transfers` work on context transfers (`:203-241`); `t3_thread_search` is bounded, unpaginated (`:243-255`).

### 1.5 Scheduler, webhooks, secrets (`TK/orchestrator/tools.ts:117-178`, `ST`, `S/scheduledTasks/Schedule.ts`)

- Types: `interval {everyMs}` with a 60 s floor (`C/scheduledTask.ts:26`), `fixed_time {timeOfDay, weekdays}` in the server's local zone (`ST:271`), `webhook`.
- A bound tick is `sendToThread(mode: "queue")`: it never steers and waits behind any active turn (`ST:815-831`).
- Ticks do not coalesce: an in-memory guard only stops two hand-offs of one task at once (`ST:712-727`), and `next_run_at` advances from the hand-off (`ST:845`), so a busy thread collects one queued run per tick.
- `lastRunStatus: succeeded` means the message was dispatched, not that the turn finished (`TK/thread/tools.ts:257-272`).
- A tick un-settles and un-snoozes its thread (`ORC:4672-4712`); an archived or deleted thread makes each tick fail while the task stays enabled.
- After downtime an overdue interval fires once, and a fixed-time run more than 10 minutes late is skipped (`Schedule.ts:76-96`).
- A failing task is never disabled and has no backoff; tasks persist in SQLite and a run interrupted by a restart is marked failed (`ST:924-978`).
- Unbound runs launch a fresh thread on a hard-coded `baseRef: "main"`, `startFromOrigin: true` worktree (`OMS:237-243`).
- Webhooks: URL via the T3 Connect relay only (`ST:74-95`), 60 requests per task per minute (`ST:66-67`), at most 20 queued deliveries (`ST:64-65`), 1 MiB body (`S/scheduledTasks/webhookRoute.ts:17-18`), prompt cap 120k.
- Signature: HMAC-SHA256 over the raw body with header, hex or base64, and prefix (`S/scheduledTasks/webhookVerification.ts:17-36`); no timestamp scheme.
- Dedupe: only relay deliveries, by the relay's delivery ID and a signed proof (`S/scheduledTasks/RelayDeliveryProof.ts:208-245`; `ST:1486-1510`); nothing reads `X-GitHub-Delivery`.
- The prompt sees the request only through `{{body.x}}`, `{{headers.x}}`, `{{query.x}}` placeholders (`S/scheduledTasks/webhookTemplate.ts:1-21`).
- `request_secret` blocks on a private card, returns a one-use, project-scoped `secretRef` (24 h TTL), whose only consumer is a webhook signature (`S/secrets/SecretRequests.ts:203-276`); the secret is then stored in plain text in `scheduled_tasks.webhook_secret`.

### 1.6 Workflows

- A "workflow" is Claude Code's own Workflow tool, detected by task type `local_workflow` (`O2/Adapters/claudeWorkflowProgress.ts:10`; `CLA:7331-7406`).
- `t3_workflow_stop` stops a whole workflow by its coordinator `subagentId` from the `activity` view (`TK/orchestrator/tools.ts:105-115`; `TMS:1060-1143`); Claude only.
- A running workflow pins idle release and blocks auto-settle, but an explicit settle kills it (`CLA:9116-9141`; `ORC:3419-3500`).

### 1.7 Pull requests (`TK/pullRequests/tools.ts`)

| Tool | Def | Notes |
|---|---|---|
| `link_pull_request` | `:278-289` | URL or repo+number; "settles the thread when it merges" (subject to settings). |
| `unlink_pull_request` | `:291-303` | Idempotent. |
| `list_thread_pull_requests` | `:305-320` | Host state, draft, head and base, and `stack` (`native` or `derived`, position, size) plus bottom-to-top `chains` (`:246-276`). |
| `watch_pull_request` | `:322-334` | See section 3. Refused for subagents (`ORC:2499-2510`) and settled or archived threads (`ORC:2486-2498`). |
| `unwatch_pull_request` | `:336-348` | Keeps the link. |
| `write_pull_request_guides` | `:384-398` | Up to 20 PRs; a server-side model writes a reviewer tour from a temporary checkout; joins a running guide for the same head. |
| `read_pull_request_guide` | `:400-412` | Returns guide, run state and `stale` after a push; never starts a run. |

There is no MCP tool to merge, enable auto-merge, update a branch, merge a stack or delete a branch; those are UI-only `PullRequestAction`s (`C/pullRequest.ts:80-102`, `:1115-1130`).

### 1.8 Worktree, project, environment, display, device

- `t3_worktree_handoff` moves the calling thread from root into a new worktree, one way, queuing a continuation prompt; uncommitted edits stay behind (`S/mcp/WorktreeMcpService.ts:140-450`).
- `t3_worktree_status` and `t3_worktree_list` read bindings and git worktrees (`:479-499`; `TK/worktree/handlers.ts:14-38`).
- `t3_project_*` list, read, create (managed repo when no root), update, delete (soft), clone (`TK/project/tools.ts:45-102`).
- `t3_environment_read` and `t3_environment_preferences_update` (thread env mode, start-from-origin, activity profile) (`TK/environment/tools.ts:54-66`).
- `html_render` pins a page above the final reply, 512k chars; `html_preview` is a headless-Chrome screenshot (`TK/html/tools.ts:18`, `:70-80`).
- `preview_*` drive a watchable browser tab; `device_*` drive simulators and need opt-in settings (`C/settings.ts` `enableAgentDeviceAccess`, default false).
- `t3_attachment_prepare_upload` and `t3_thread_send_attachments` move files between threads (`TK/attachment/tools.ts:47-67`).

### 1.9 What survives a T3 server restart

- Survives: threads, runs, queued runs (but held), scheduled tasks, PR links and watches, delegated tasks and their result transfers (finalization replays from events, doc `:456-459`).
- Lost: every provider process and its background work (Monitors, background Bash, background agents), recorded as `run.background-work-cancelled` and told to the next run (`O2/ProviderRuntimeRecoveryService.ts:592-612`; `O2/RestartBackgroundNote.ts`).
- Running and waiting runs become `cancelled` (`ProviderRuntimeRecoveryService.ts:198-239`); queued runs get `queueHeld: true` (`:306-327`).
- With `continueThreadsAfterServerUpdate` (default true, `C/settings.ts:1136-1142`) T3 sends "Continue where you left off." to an interrupted turn, at most 3 times in a row (`O2/RestartContinuation.ts:28-31`, `:122-193`).
- In memory only: PR-watch read caches (a restart re-reads each PR once, `PRW:91`), the scheduler's in-flight guard, webhook deliveries accepted but not yet run, and a pending self-settle.

### 1.10 What notifies Bryce's phone

- Push is decided per thread from `projectThreadAwarenessV2` (`packages/shared/src/agentAwareness.ts:58-120`) and alerted by the relay (`infra/relay/src/agentActivity/agentActivityAlerts.ts:57-105`).
- Alerts fire on entering "waiting for input" or "approval needed", and on a fresh (2-minute) transition to completed or failed.
- A completed run counts as still running when `backgroundWorkHoldsCompletion` holds: subagent, monitor, background agent or workflow, and a T3 PR watch; background Bash does not (`PBW:73-88`, `:289-302`; `CLA:2051-2079`).
- Subagent-lineage threads, including every `delegate_task` child, never push (`agentAwareness.ts:62`).
- Scheduled-tick runs, PR-watch wakes and child completions are ordinary runs: when one completes with no hold, it pushes.
- Preferences are global per user (`notifyOnApproval`, `notifyOnInput`, `notifyOnCompletion`, `notifyOnFailure`, `agentActivityAlerts.ts:37-54`); there is no per-thread mute, and snooze does not silence push.

## 2. Session lifecycle

### 2.1 Idle release

- 30 idle minutes, then release, unless the adapter reports pending work, which pins for up to 4 hours (`PSM:54-55`, `PSM:1173-1252`).
- The 4-hour budget restarts on every provider event (`PSM:1269-1306`, `PSM:2026-2035`, `e4ef8d36`), so it is 4 hours of provider silence, not 4 hours after the last turn.
- Claude pending work: any roster entry (background Bash and Monitor are both `local_bash`), any running session subagent (background agents, workflows), or a buffered wake (`CLA:2052-2072`, `CLA:9116-9141`).
- App-side work does not pin: PR watches, scheduled tasks and `delegate_task` children live in the server, not the CLI (`O2/ProviderRuntimeRecoveryService.ts:101-103`).
- A turn in flight never idle-releases, even a hung one (`PSM:1183`); there is no in-process reaper for a turn that never ends (no watchdog found; unconfirmed absence).
- Release kills the CLI and all its background work and revokes the MCP credential (`PSM:1050-1160`); since `519d64f6` (not on odin) the leftover roster is cleared so the thread stops showing Waiting.
- Codex is a shared runtime: its per-thread unload waits on pending work with no 4-hour cap (`PSM:1696-1747`).

### 2.2 How work reaches a released, settled or stopped thread

- Every wake (message, tick, PR-watch wake, child completion, child question) is a `message.dispatch` that starts a run, which reopens the session and resumes the native conversation (`O2/ProviderTurnStartService.ts:531-549`, `:672-689`).
- If resume fails, T3 starts a fresh native session with a full-thread summary handoff (`:694-730`).
- Settled thread: a message un-settles it and runs (`ORC:4672-4691`); a PR-watch wake is refused (`ORC:2392-2403`).
- Delegated completions are disposed only when the parent is archived or deleted (`ORC:9958-9976`); settling the parent cancels any completion wake already queued (`ORC:2650-2661`, `:2709-2718`).
- Archived thread: sends are refused and its queued runs cancelled (`TMS:797-801`; `ORC:3357-3375`).
- User Stop: queued runs become held, buffered wakes cancelled, PR watches ended, delegated tasks stopped (`ORC:8863-8940`); a new message to the idle thread still starts at once.
- Usage limit: the queue is left untouched until a continuation runs (`ORC:1312-1323`); the doc says queued messages "run after the continuation finishes" (`docs/user/thread-sidebar.md:200-201`).
- Auto-resume at the limit's reset (`O2/UsageLimitRecoveryWorker.ts:11-72`) needs a `resetAt` on the failure (`:17-33`).
- Claude gets `resetAt` only from a `rate_limit_event` with `resetsAt` or a 9router-style wrapped 429 (`CLA:2792-2816`, `CLA:6764-6818`); a bare 429 through claude-proxy has none, so odin's `autoResumeLimitedThreads: true` may never fire (unconfirmed).

### 2.3 What "running" and "waiting" mean

- Run statuses: `preparing, queued, starting, running, waiting, completed, interrupted, failed, cancelled, rolled_back` (`C/orchestrationV2.ts:455-466`).
- `waiting` is post-turn drain: the turn ended and background work holds the thread (`ORC:545-549`; `PBW:32-46`; Claude's "Waiting roster", `CLA:2047-2050`; sidebar comment in `e536bfd3`).
- A question for the user does not produce `waiting`; it is a pending runtime request on a `running` run, visible as `pendingRequestCount` in `t3_thread_read` (`OMS:771`).
- Stale states: a PR watch keeps a thread "Waiting"/Working for the watch's life (`PBW:289-302`); a Monitor whose end notice never arrives keeps it Waiting until release; a turn that never terminates reads `running` until a server restart.

### 2.4 Settlement and auto-settle

- Defaults: settle after 3 idle days and on merge (`C/settings.ts:95`, `:1207-1215`); odin has both off.
- Candidates exclude archived, overridden, pinned, auto-settle-disabled, pending request, live run, held background work, and a fresh queued turn (`TSS:139-164`).
- Pinning does block auto-settle in code (`TSS:144`), contrary to `docs/user/thread-sidebar.md:65`.
- Any linked PR still open (or never synced) blocks auto-settle entirely (`TSS:210`).
- A merged or closed PR settles the thread only if it closed at or after the last human-authored message, so agent-only threads such as coordinators qualify (`TSS:110-136`).
- `sidebarAutoSettleKeepPullRequests` (`bf8ffe81`, not on odin) spares threads with a PR from inactivity settlement, not from settle-on-merge (`TSS:239-242`).
- Settle is refused while a run is preparing, starting, running or waiting, with an approval pending, or with a user-queued message (`ORC:2664-2690`).
- Settle cancels queued notification and completion wakes, cancels message-capable questions, clears PR watches, and detaches every live session, which kills Monitors and background agents (`ORC:2650-2718`, `:2872-2888`, `:3419-3500`).
- Settle runs the project's `runOnSettle` scripts in the thread's own worktree (`C/t3ProjectFile.ts:46-50`; `TSS:568-613`).
- Scheduled tasks are untouched by settle; their next tick un-settles the thread.

## 3. Pull request features

### 3.1 What `watch_pull_request` actually does

- A 2-minute sweep reads each watched PR once per project (`PRW:43`, `:572-647`), gated by GitHub's batched fingerprint of state, head and check counts by state (`packages/source-control-github/src/server/gitHubPullRequestJson.ts` `buildPullRequestWatchFingerprintsGraphQlQuery`).
- Wakes on four changes only (`prw:17-21`):
- `checks-failed`: any check that fails, is cancelled or needs action, reported as soon as it fails, per check name (`prw:33-62`).
- `checks-passed`: once per head when every gating check is done and green; the gate is the base's required checks, or all checks when none is required; skipped and neutral count as green (`prw:64-77`).
- `remarks`: comments and reviews newer than the watch start, by anyone except the viewer's own login; edits count as new (`prw:80-99`).
- `conflicting`: the branch starts to conflict; only a clean answer clears it (`prw:101-106`).
- Not reported: merge (silent end, `PRW:524-530`), base moving, new commits, CI starting, Bryce's own comments.
- Ends on merge, close (with a wake), 8 failed reads in a row (with a wake, rate limits excluded), 10 comment-only wakes in a row, settle, archive, Stop, or `unwatch` (`PRW:45`, `:120-127`, `:328-340`; `prw:13`).
- Wakes are queued notification messages behind the active turn (`ORC:2405-2418`), with a timeline notification of outcome failed, completed or updated (`prw:183-219`).
- A watch is a `monitor` hold: the thread stays in Working, its completed turns do not push, and it blocks auto-settle (`PBW:289-302`; `TSS:149`).
- It does not keep the provider session alive, and it does not need to.

### 3.2 Why builders saw one "checks passed" and nothing more on 2026-10-14

- The rerun fix `a4180751` ("no longer reports passed while a second run of a check is still going") was already on odin.
- In code, a gating check that goes pending after "passed" resets `passed`, and its later success wakes again (`prw:64-77`; pending outranks finished runs in dedupe, `gitHubPullRequestJson.ts` `toCheckEntries`).
- So the miss means the suites' check was not in T3's gate, for example a required set holding only the skipped `check`, or job names that differ between the draft and ready runs (inference, unconfirmed).
- Builder rule 7's own `gh pr checks --watch` stays the right call (`OR/coordinator/builder-rules.md:13`).

### 3.3 Merges, branches, stacks, guides

- Merge detection: a merge made in T3 publishes a merge event; a merge outside T3 is found when a run that ran `gh pr merge` ends, or by the next sync sweep (`docs/internals/overview.md:87-96`); none of these wakes an agent.
- `#19257` (`339179f5`) adds a `delete-branch` button on a closed or merged PR's detail page, web and mobile; it is not automatic and not an MCP tool.
- Settled-worktree cleanup (`21bedfb1`, `worktreeSettledAfterDays`, default off) removes only T3-managed worktrees, deletes ignored files such as `.env`, and keeps the branch (`S/storageCleanup.ts:473-520`, `:663-674`).
- Delegated isolation worktrees start on temporary `t3/<8 hex>` branches (`packages/shared/src/git.ts:15`), which explains the leftover `t3/*` branches in `hzbook-run-results.md:307`.
- Stacks: native host stacks and base-derived chains are read and shown (`C/pullRequest.ts:456-460`); stack merge and stack rebase exist with `expectedStackHeads` as a head guard, UI only (`C/pullRequest.ts:1115-1117`; `packages/source-control-github/src/server/githubStackActions.ts`, `githubStackRebase.ts`).
- No merge queue, no MCP merge, no MCP auto-merge.

## 4. The T3 team's own workflow

- One instruction set: `CLAUDE.md` is `@AGENTS.md`, and `.claude/skills` mirrors `.agents/skills` (`test-t3-app`, `test-t3-mobile`, `contribution-triage`).
- "Most T3 Code contributions will come from T3 Code itself, often controlled remotely" (`AGENTS.md:41`).
- Every user capability must also be an MCP-reachable service method, and every way in needs a way out (`AGENTS.md:72-74`).
- Verification is the smallest proof; "Do not run repo-wide checks... CI owns the full suite"; tests drain the effect worker, never sleep (`AGENTS.md:98-103`).
- PRs: only when asked, conventional plain-language titles, body ends with model and harness, "One request is one PR" (`AGENTS.md:107-114`).
- Babysitting: poll checks and comments newer than the last push, verify each bot finding against the source, dismiss false positives with a reason, stay quiet when nothing is new, stop when bots are green (`AGENTS.md:115`).
- CI: one aggregator job `Check` is the only required check (`.github/workflows/ci.yml:481-514`); PR runs cancel on new pushes, main runs never do (`ci.yml:12-14`); `test_server` runs 6 duration-balanced shards; 10-minute job timeouts on Blacksmith runners.
- No `merge_group` trigger anywhere, so no merge queue; no workflow enables auto-merge.
- Merge pattern: 550 of 550 commits are single-parent squash merges by GitHub, about 85 merges per full day (peak 124 on 2026-10-10, 18 in one hour on 2026-10-14).
- With no merge queue at that rate, branch protection almost certainly does not require up-to-date branches (inference).
- Agent authorship: 262 of 313 co-author trailers name an AI, 217 of them Claude Opus 5.5; Theo 91 of 93 commits, Julius 83 of 112.
- Maintainers re-land contributor PRs as their own PRs with co-author credit (`f4df7947`, `39aeaf40`, `acb90279`).
- No stacks or integration branches in evidence; the product supports stacks but the team ships single squashed PRs.
- Review bots are advisory: CodeRabbit with `request_changes_workflow: false` and self-approval for members (`.coderabbit.config.ts:3-15`); Macroscope auto-approval criteria and two non-blocking check-run agents (`.macroscope/approvability.md:1-7`; `.macroscope/check-run-agents/*.md`); a Cursor hygiene webhook (`.github/workflows/cursor-hygiene-webhook.yml`).
- Outside contributions: vouch labels (`.github/workflows/pr-vouch.yml`), size labels (`pr-size.yml`), and an agent triage skill that fails closed (`.agents/skills/contribution-triage/SKILL.md:28-61`).
- Live verification of orchestration runs against real providers: delegated completion after the parent ends its turn, active-turn delivery, background-command wake, nested delegation (`docs/operations/background-verification.md:7-42`).
- Lesson for us: they get volume from one required aggregate check, squash merges without up-to-date enforcement, advisory bots, and agents that babysit only their own PR; they accept occasional red main and fix forward.

## 5. Recent orchestration changes and what they imply

- Child questions reach the parent: `fdacb3a3` queues a wake for a blocked `delegate_task` child's question; `924fb0c4` ends a blocking wait with `hasPendingQuestion`; `c814e51a` dismisses a cancelled child's questions; `f4df7947`, `109aaae6` surface them in UI (all 2026-10-14).
- Isolation: `25629a76` adds `delegate_task isolation: "worktree"` from the parent's local commit (2026-10-14).
- Restart robustness: `b9ad3daf` restart continuation on by default, capped at 3 (2026-10-11); `22af947e` restarts no longer stall on old result deliveries; `eeaac49a` "update all" no longer runs agents twice or loses background work.
- Idle and Waiting: `e4ef8d36` activity restarts the idle pin (2026-10-10); `519d64f6` settled and idle-released threads stop showing Waiting; `e536bfd3` Waiting gets an icon and a timer from turn end.
- Wakes and snooze: `05e4f888` snooze allowed while automatic wakes are queued; Stop cancels buffered wakes but keeps durable queued messages; `d0a73b56` notification-woken threads page history.
- Settle and cleanup: `bf8ffe81` keep-PR-threads option; `21bedfb1` settled-worktree removal; `339179f5` manual branch delete; `a5b48245` settle refusals say why.
- PR watching: `a4180751` rerun-aware "passed"; fewer host reads (`06a84de3`, `21af72f7`); review guides over MCP (`18656a34`).
- Not touched in this window: merge wakes, scheduled-task delivery, sending into settled threads, an MCP merge or branch-delete tool.
- Trend: T3 is making the parent-child tree the reliable unit (questions, isolation, restart delivery, cancellation cascades) and making settle the cleanup trigger; it is not moving toward merge orchestration.
- Implication: the more of our run that is a `delegate_task` tree under the coordinator, the more of T3's recent hardening we inherit for free.

## 6. Ranked verdicts

### 6.1 Our workarounds and scripts against T3 primitives

1. **Monitor keep-alive and 29-minute heartbeats** (`OR/coordinator/skill/070-staying-alive.md:3-6`, `090-watcher.md`, `OR/coordinator/bin/watch-run.sh:1-22`).
   Verdict: self-inflicted, simplifiable.
   T3 resumes a released conversation for every kind of wake (`O2/ProviderTurnStartService.ts:531-549`); only the in-session watcher needs the process alive.
   The other job of the Monitor, holding back the "finished" push, is also done by a T3 PR watch, which holds without a process (`PBW:289-302`; `agentAwareness.ts:103-108`).
   Moving merge detection out of the session (6.2 item 3) and letting the coordinator own PR watches (6.2 item 2) removes the heartbeat turns (about 10 per 5-hour run, `hzbook-run-results.md:97`).
   Our note "about four and a half hours after your last turn" is also off: it is 4 hours after the last provider event (`PSM:1269-1306`).
2. **Builder report message plus `liveness.mjs` "ended without a report"** (`OR/coordinator/skill/030-builders.md`, `OR/coordinator/bin/liveness.mjs:1-12`).
   Verdict: replaceable if builders become `delegate_task` children (6.2 item 1).
   A child's terminal turn is a durable completion that wakes the parent with the result summary (`ORC:9931-10120`; `OMS:2054-2057`), so "pushed and ended its turn without reporting" (`hzbook-run-results.md:142`) cannot happen.
   `liveness.mjs` would shrink to the hung-turn case, which T3 still does not reap (`PSM:1183`).
3. **Doorbell inbox** (`OR/lib/inbox.mjs:1-10`, `OR/cos/skill/050-inbox.md`).
   Verdict: keep the inbox, drop one fear.
   A message to a settled CoS thread is not lost: it un-settles and resumes the thread (`ORC:4672-4691`); a message to an idle-released thread resumes it too.
   Real losses T3 still allows: archived targets (refused), queues held after Stop or a T3 restart that no agent can release (`ORC:8863-8940`; `ProviderRuntimeRecoveryService.ts:306-327`), plan-mode senders (mode ceiling), and a stale `cos.id`.
   The inbox's ack cursor and per-key dedupe across sessions are things T3 does not offer (1.1).
4. **CI wait for builders** (`OR/coordinator/builder-rules.md:13`, watcher CI lines and nudges in `090-watcher.md`).
   Verdict: keep, with the cause now located.
   T3 reports "passed" for the required gate only, once per head (`prw:64-77`); if the suites are not in that gate, a builder never hears of them.
   With builders as children, the coordinator could own a PR watch on each ready PR for failures and conflicts, while the builder still waits on `gh pr checks --watch`.
5. **Audit tick** (`OR/coordinator/skill/080-audit-tick.md`).
   Verdict: already the right T3 primitive; tune it.
   Ticks queue behind a busy turn and pile up without coalescing (`ST:712-727`, `:845`); a 20-minute tick during a long turn or a limit window leaves several queued runs, each a turn.
   Each tick turn that ends with no hold pushes the phone (1.10); in the coordinator the watcher Monitor or a PR watch holds it, in the CoS nothing does (see 6.3 item 3).
6. **Usage-limit recovery** (`080-audit-tick.md`, 49 to 68 minutes on 2026-10-14).
   Verdict: T3 has the primitive and odin enables it, but it needs a reset time the proxy may not supply (2.2).
   Check `statev2.sqlite` for `usage_limit` failures with `usageLimitResetAt` on 2026-10-14; if absent, keep the 20-minute tick as the recovery.
7. **Restart section** (`OR/coordinator/skill/100-restart.md:4-11`).
   Verdict: keep; T3 confirms the constraint.
   `task_status` rejects tasks of another parent (doc `:293-295`), so restarting in the same thread through the tick (bindToCurrentThread) is the only path that keeps child wakes.
   T3 restarts now continue the interrupted turn automatically (`O2/RestartContinuation.ts:122-193`), but held queues stay held until Bryce resumes them.
8. **`cleanup.sh` and Finish settle** (`OR/coordinator/bin/cleanup.sh`, `130-finish.md`).
   Verdict: partly replaceable.
   A `runOnSettle` script in each product repo's `t3.json` can stop browser sessions and environments per worktree whenever a builder thread settles (`C/t3ProjectFile.ts:46-50`).
   `worktreeSettledAfterDays` (after an upgrade) can remove settled T3 worktrees, but it keeps branches and deletes ignored files, so branch deletion stays ours.
9. **`merge-ready.mjs`, `main.mjs`, approvals, `state.mjs`** (`OR/coordinator/bin/`).
   Verdict: no T3 replacement.
   T3 has no MCP merge, no merge queue and no head-guarded merge for agents; its own team runs without a queue (section 4).
10. **Stack bookkeeping** (`state.mjs carry`, `base=` in `030-builders.md`/`050-merge.md`).
    Verdict: small simplification.
    `list_thread_pull_requests` returns native or derived stack position and chains (`TK/pullRequests/tools.ts:246-276`) once PRs are linked to the coordinator.
11. **`created.tsv` task rows for a fresh-thread restart** (`100-restart.md:11`).
    Verdict: small simplification.
    `t3_thread_list` items carry `parentThreadId` and `relationshipToParent` (`C/orchestratorMcp.ts:337-338`), so a fresh thread can find the old coordinator's children without the TSV.
12. **`lessons.mjs` reading `statev2.sqlite`** (`OR/cos/bin/lessons.mjs:13`).
    Verdict: keep; `t3_thread_read` pages everything, but only an agent or an OAuth outside client can call it.
13. **Never `AskUserQuestion`, never plan mode** (`120-asking-bryce.md`, `OR/cos/skill/080-delegating.md`).
    Verdict: keep both; a pending question still blocks the turn, and the mode ceiling still refuses a plan-mode sender (`OMS:585-597`).
14. **`load-ok.sh`**: no T3 equivalent found.

### 6.2 Unused T3 primitives that could help, ranked

1. **Builders as `delegate_task` children with `isolation: "worktree"`.**
   Completion is the report; a fix round is `t3_thread_send` to the `childThreadId`, which opens a fresh task and wakes the coordinator again (`TK/orchestrator/tools.ts:238`).
   Children never push the phone (`agentAwareness.ts:62`), while a top-level builder ending on a background `gh pr checks --watch` pushes "Agent finished" each time, since background Bash does not hold (`PBW:79-88`) (likely; check the phone).
   Their running turns hold the coordinator's own completion push (subagent hold), and `task_cancel` and Stop cascade to them.
   Bryce can open a child thread and type in it (`ChatView.tsx:2144`), which answers the "a builder must be a conversation Bryce can open" objection (`docs/plans/snapcaster-agent-workflow.md:27`), though the user doc says otherwise (`thread-sidebar.md:221`).
   Costs: the worktree starts from the coordinator checkout's `HEAD` on a `t3/<hex>` branch, so the brief keeps its `git fetch && git reset --hard origin/<base>` and branch creation; a child cannot watch PRs; settling or archiving the coordinator drops queued completions; restart must stay in the same thread.
   The injected instruction "Do not use `t3_thread_send` on `childThreadId` to continue a delegated review" (`orchestrationInstructions.ts:11`) is about review rounds; builder follow-ups are the case the tool explicitly supports.
2. **Coordinator-owned `watch_pull_request` on each ready PR.**
   It replaces the watcher's CI-failure, conflict and reviewer-comment lines, and it is a process-free hold that keeps the coordinator quiet and in Working.
   It cannot replace merges, base moves or Bryce's own comments; bot comment edits (Vercel previews) count as wakes and can exhaust the 10-wake cap.
3. **A GitHub webhook task bound to the coordinator or CoS for merges** (`schedule_task {type:"webhook", signature}` with `request_secret`).
   Bryce's probe already got a relay URL (`docs/plans/hzbook-pstack-takeover.md:174`).
   Subscribe narrowly (pull_request), and template only `{{body.action}}`, `{{body.pull_request.number}}`, `{{body.pull_request.merged}}` so the turn is short.
   Each delivery is one queued turn with no coalescing (cap 20 queued, 60 per minute), so it suits rare events like merges, not check runs.
   With items 2 and 3, `watch-run.sh`, its Monitor and the heartbeat could go.
4. **Turn auto-settle-on-merge back on for builder threads after upgrading to a nightly with `bf8ffe81`.**
   Builders that link their PR settle when it merges, which replaces "settle the builder's thread" in Merge step 5 and triggers `runOnSettle`.
   Risk: a coordinator thread that links PRs and has no hold also settles on its last merge mid-Finish (`TSS:110-136`); keep coordinators unlinked or held, since per-thread opt-out is UI-only.
5. **`runOnSettle` scripts in the product repos' `t3.json`** to stop `playwright-cli` sessions and per-worktree environments (`hzbook-run-results.md:112-115`).
6. **`t3_queue_list`, `t3_queue_cancel`, `t3_queue_promote_to_steer`** so the CoS or a coordinator can see stale ticks and doorbells piled in a busy thread, drop duplicates, and steer an approval into an active turn.
7. **`write_pull_request_guides`** for Bryce's approval step: a reviewer tour per merge-ready PR in its Guide tab, marked stale after a push; it needs the guide model enabled on the server.
8. **An OAuth outside-agent MCP client for our scripts**, so `state.mjs` and `main.mjs` deliver their own doorbells with a stable idempotency namespace (`McpOAuth.ts:574`) and agents stop relaying printed doorbells; bold, needs token handling.
9. **`run_scheduled_task_now`** on a run's tick as "status now" (already in the housekeeping list, `hzbook-pstack-takeover.md:175`).
10. **`t3_thread_read` `pendingRequestCount`** as the real "stopped on a question" signal (see 6.3 item 1).

Still rejected, with fresh evidence: `t3_thread_wait` in the CoS (max 60 minutes, blocks a turn); `watch_pull_request` as the only merge signal (silent on merge); thread fork and merge-back (no workflow need found).

### 6.3 Bugs and mismatches in our skills

1. **The CoS misreads `waiting`.**
   `OR/cos/skill/020-start.md:8`, `030-what-next.md:5` and `050-inbox.md:18` treat `statuses: ["waiting"]` as threads stopped on a question.
   In T3 `waiting` means the turn ended and background work holds the thread (2.3), so every coordinator with a live watcher Monitor is listed as "waiting on Bryce", and a real question is missed.
   Use `t3_thread_read` `pendingRequestCount`, or `t3_pending_request_list` per live thread.
2. **`clientRequestId` dedupe is per provider session.**
   `OR/coordinator/skill/040-checking.md:12` and `snapcaster-agent-workflow.md:25` say a retry with the same request id starts no second checker.
   That holds only within one session (`McpSessionRegistry.ts:127`, `:133`; `OMS:604-680`); after a release or restart, look up `created.tsv` or the child list before retrying.
3. **The CoS tick probably buzzes the phone.**
   A tick turn that completes with nothing held is a terminal transition that pushes (`agentAwareness.ts:103-108`; `agentActivityAlerts.ts:72-105`), and the CoS runs no Monitor or watch.
   `050-inbox.md:15` assumes only doorbell turns alert; confirm on the phone, then either accept it or hold the CoS with something that wakes it anyway.
4. **Staying-alive arithmetic** in `070-staying-alive.md:4` (see 6.1 item 1).
5. **Pinning**: the 2026-10-14 rationale "the pin guarded nothing" holds only because auto-settle is off; in code a pin does block auto-settle (`TSS:144`).

## 7. Unconfirmed

- Whether the receiving model sees `senderThreadId` or only the message text.
- Whether claude-proxy delivers `rate_limit_event.resetsAt`, which decides if auto-resume ever fires on odin.
- The exact check names and required set on HzBook PRs that made T3's watch go quiet on 2026-10-14.
- Whether a fast CoS tick turn is observed as running by the relay before it completes, which decides if it pushes.
- Whether the web UI lets Bryce type into an app-owned child thread in practice (server and composer code say yes).
- Whether the agent is told about background work lost to an idle release (only the restart path writes that note).
- That no in-process reaper exists for a hung turn (absence from grep only).
