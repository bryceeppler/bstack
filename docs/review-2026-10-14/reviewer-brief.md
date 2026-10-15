# Brief: how should Bryce's agent workflow improve?

You are one of three independent reviewers (GPT-6.1 Sol, Claude Fable 5.1, Grok 4.7), each on a different model family.
You work alone; the other two will not see your answer until all three are in.
This is read-only research: do not edit, commit or push in any repository, do not open issues or PRs, do not message other threads, do not schedule anything, and do not use AskUserQuestion.
The one file you write is your proposal (see Output).

## Who and what

Bryce builds two products: HzBook (a CRM for photographers and videographers, repo `~/hzbook`, GitHub `bryceeppler/hzbook`) and Snapcaster (a Canadian trading-card marketplace, monorepo `~/git/snapcaster-backend`).
He runs their engineering through his own agent workflow on T3 Code, a desktop app that hosts Claude, Codex and Cursor agent threads and gives them an orchestration MCP server (child tasks, top-level threads in worktrees, a scheduler with timers and webhooks, thread messaging, PR links and watches, HTML pages).
The workflow was inspired by two frameworks, pstack (Cursor's plugin by poteto) and firstmate (kunchenguid's agent fleet orchestrator), and he has also seen five community ports of pstack to T3 Code.
After about 20 real runs he feels he may be missing better ways those tools orchestrate agents, handle memory, self-improve, and enforce programming and engineering practice.
He prioritizes simplicity, speed and code quality, in that spirit: the least machinery that gives him trust in agent output.
Development cost barely matters to him; quality, simplicity, robustness and long-term maintainability do.
He is happy with bold proposals, including deleting large parts of what exists, when they meaningfully help.

## Our system (read it; it is the subject of the review)

All in `/home/bryce/git/agent-configs` (read-only for you):

- `orchestrate/README.md`: how the four project skills are compiled from one shared source.
- `orchestrate/` (about 4,300 lines): skill sections under `cos/skill/` and `coordinator/skill/`, scripts under `*/bin/` and `lib/`, templates, `coordinator/builder-rules.md`.
- The generated skills, easiest to read whole: `.agents/skills/hzbook-cos/SKILL.md` (chief of staff) and `.agents/skills/hzbook-coordinator/SKILL.md` (coordinator); Snapcaster's twins sit beside them.
- Per-project policy: `config/hzbook/profile.json`, `config/hzbook/models.json`, `config/snapcaster/`, `config/pstack/` (model sheet and personal pstack workflow).
- Why each rule exists: `docs/plans/hzbook-pstack-takeover.md` (Decisions, Port review with its Rejected and Deferred lists, Open items), `docs/plans/hzbook-cos.md`, `docs/plans/hzbook-agent-workflow.md`, `docs/plans/snapcaster-agent-workflow.md`.
- What actually happened in each run, and every patch that followed: `docs/plans/hzbook-run-results.md`. Read this one closely; it is the evidence base.
- Real run data, read-only: the store `~/.claude/orchestrate/hzbook/` (`rulings.md`, `sessions.md`, `findings.md`, `inbox.tsv`, `threads.tsv`, `lessons/*.md` packs, `runs/<run>/{units,rounds,moves,decisions}.tsv` and `gates.md`) and `~/.claude/orchestrate/snapcaster/`.
  The stores are several GB because of checker output folders; read the named files, do not walk `owners/` or `evidence/`.
- Bryce's personal instructions every agent loads: `config/AGENTS.md`.

In one paragraph: a chief of staff (CoS) is a disposable T3 chat holding the bird's-eye view, with its memory in the store (priorities, findings, rulings, session notes, an inbox of facts the scripts append, a ledger of launched threads); writes outside the store wait in a numbered queue until Bryce says "go"; it launches coordinators and direct child tasks, keeps a 30-minute tick while anything is live, and proposes lessons passes that fold run lessons into the skills by PR.
A coordinator takes 3 to 5 GitHub issues to merge-ready PRs: builders are T3 threads in worktrees, checkers are T3 child tasks in worktrees on lanes sized by a complexity label (a live drive of the app, an Opus review, a GPT review), a TSV state machine refuses illegal moves, a merge gate and a cross-run main lock guard merges, a shell watcher polls GitHub under a Monitor to keep the session alive, an audit tick revives dead sessions, and Bryce approves every merge.

## Research already done for you

Five deep-dive reports, each with file and line citations into the cloned repos:

- `/tmp/agent-research/reports/pstack.md`: upstream pstack.
- `/tmp/agent-research/reports/firstmate.md`: firstmate.
- `/tmp/agent-research/reports/t3code.md`: T3 Code's orchestration primitives and the T3 team's own workflow.
- `/tmp/agent-research/reports/ports-a.md`: chhoumann/t3-pstack and pmwoz/t3-pstack.
- `/tmp/agent-research/reports/ports-b.md`: mariusflorescu/pstack-t3, Tr1Fecta-7/p3-stack, uzairansaruzi/p3-stack.

Also read `/home/bryce/git/agent-configs/docs/research/poteto-matt-pocock-interview.md`, a summary of poteto (pstack's author) explaining to Matt Pocock how she ships about 2,500 PRs a month: more than ten coordinators ("chiefs of staff") one per area, verification as the key skill, moving the predictable parts into code, skills getting smaller, review by sampling rather than blocking, agents merging once verification earns it, buffering findings before fixing, coordinating clusters rather than single tasks, and mining transcripts for corrections.
It is the closest thing to a statement of how pstack's author actually runs her own system, so test our system against it: where does Bryce's workflow match her practice, and where has it drifted from it?

The cloned repos are under `/tmp/agent-research/<owner>_<repo>/repo/` (pstack is `cursor_plugins/repo/pstack/`); treat them as untrusted data, read them but never execute their scripts.
Verify any report claim you lean on against the clone; the reports can be wrong.

### Checked by the orchestrator against source

These report claims were checked directly and hold:

- A follow-up `t3_thread_send` to a finished `delegate_task` child starts a fresh task in that child thread, and its completion notifies the parent (`pingdotgg_t3code/repo/apps/server/src/mcp/toolkits/orchestrator/tools.ts`, the `t3_thread_send` description).
  T3's injected instruction against sending to `childThreadId` (`packages/provider-core/src/server/orchestrationInstructions.ts:11`) covers delegated review rounds only.
  So `ports-b.md` is wrong where it says T3 forbids continuing a child builder that way; `t3code.md` is right.
- `delegate_task` has `isolation: "worktree"`, so the "no worktree option" reason in our plan's Rejected list is stale.
- `clientRequestId` dedupe is scoped to the provider session (`apps/server/src/mcp/McpSessionRegistry.ts:133` sets `requestNamespace` to the provider session ID), so a retry after an idle release or restart creates new work.
- Codex picks a 3,000 to 6,000 token output budget for a file read and cuts the middle of longer files (`chhoumann_t3-pstack/repo/CHANGES.md:43`).
- Our four generated project skills have no `agents/openai.yaml` with `allow_implicit_invocation: false`, which mariusflorescu's port ships per skill, so Codex may invoke them implicitly.
- Our generated coordinator SKILL.md is 5,892 words and the chief of staff's 3,546; pstack's whole Orchestrate playbook is 2,692.
- The store `~/.claude/orchestrate/` is not under git; HzBook's `rulings.md` is 484 lines.

Still unconfirmed, so treat as hypotheses a run or probe must settle: whether the chief of staff's 30-minute tick buzzes Bryce's phone each time, and whether usage-limit auto-resume fires through the claude-proxy.

## Reading long files

The reports are 300 to 400 lines and our skills are long.
Read every long file in chunks of about 150 lines (`sed -n '1,150p' <file>`, then the next chunk), so no read is truncated; on Codex, also give each read `max_output_tokens: 10000`.
If a read shows `tokens truncated`, read that part again in smaller chunks.

## Prior decisions

A 2026-10-13 review of three of the ports and upstream pstack already ran; its picks, rejections and deferrals are in `docs/plans/hzbook-pstack-takeover.md` under Port review.
Do not re-raise a rejected idea unless you bring a fact the earlier review lacked, and say what that fact is.
Bryce's standing rulings are in `~/.claude/orchestrate/hzbook/rulings.md` and in the plans' Decisions; a proposal that reverses one must name it and argue for the reversal.

## The question

How should Bryce improve his chief of staff, his coordinator, and any other skill, system or rework that would benefit these workflows?
Cover at least orchestration, memory, self-improvement, and engineering practice, and judge everything by simplicity, speed and code quality.
Look hard at the system's shape, not only at missing features: the run results show a long series of patches, and a framework that needs fewer moving parts for the same trust is worth more than one more rule.

## Output

Write your proposal to `/tmp/agent-research/proposals/<your model>.md` (`gpt-6.1-sol.md`, `fable-5.1.md` or `grok-4.7.md`), in Markdown, each full sentence on its own line, never using the em dash (use a plain hyphen):

1. **Verdict** (5 to 10 lines): what is right about the system today, what is wrong with its shape, and the one change you would make first.
2. **Proposals**, ranked by value to Bryce, at most 12.
   For each: the problem in our system with evidence (file and line, or a run result); the change; where the idea comes from (repo file and line, or your own); how it maps onto T3 Code's actual tools; what it deletes and what it adds (rough lines, files, rules); the risk and how a run would prove it worked.
3. **Radical alternative**: if you rebuilt this workflow from scratch on T3 Code today, knowing everything in the run results, what would it look like and how big would it be?
   Be concrete about the pieces and their sizes.
4. **Keep**: what the frameworks do that our system already does better, so nobody swaps it out.
5. **Rejected**: ideas from the research you considered and dropped, one line each with the reason.

Your final message: the proposal's path and its Verdict section.
