# bstack Snapcaster trial: stock Autopilot against the orchestrate/ coordinator

Trial: T3 thread `mcp:9660ec81-7807-4fab-8d2b-ffeb2156be64`, stock bstack `/poteto-mode` Autopilot-full, launched 2026-10-15 15:02 UTC on snapcaster-backend #3075 and #3076 (both `complexity:small` client bugs), owners on Opus 5.5 and verifiers on GPT-6.1 Sol.
Comparison: the first Snapcaster orchestrate/ run, `2026-10-14-three-small-bugs` (#2776, #2786, #2939 small, then #3043 standard), launched 2026-10-14 16:32 UTC, the closest in size and label.
Different tickets on different days, and the comparison run spent part of its time in away mode, so these are one data point each.

## Numbers

| | bstack trial (2 small) | orchestrate/ run (3 small, 1 standard) |
|---|---|---|
| Launch to code-ready, per unit | 15, 22 min | 46 min, 2h01, 2h02, 2h27 |
| Launch to merged, per unit | 28, 57 min | 2h51, 2h51 (both at 19:23), 2h10 (#2939 merged later), 4h32 |
| Whole run, launch to last merge | 60 min | about 7h45 (#3043 merged 2026-10-15 00:16) |
| Time waiting on Bryce | 0 | merge approvals through the chief of staff (merge-ready to merged: 24 min to 1h45) |
| Questions to Bryce (gates) | 0, plus 1 escape-hatch default reported for overturning | the run's merges were his, relayed through the chief of staff |
| Rounds per unit | 1, 2 | 2, 2, 2, 2 |
| Verdicts with in-scope findings | 2 of 6 (both on #3075: one blocking, one follow-up) | ledger shows 2 of 12 ISSUES on the sibling backend-cleanup run; this run's rounds were mostly description fixes |
| In-scope findings fixed before merge | 1 (a dialog that could close mid-save and lose the failure) | description and docs fixes, one real defect in #3043 |
| Follow-ups found | 2 (harness checks shape not field rules; generate the client type from core's API doc) | filed through the coordinator |
| Coordinator turns | 12 in 60 min | not in the store |
| CI and bots | PR checks once per push on ready PRs; CodeRabbit "no actionable comments" on both; `gate:local` client e2e 213 and 214 passed before each merge | the same local gate, added that day (agent-configs #65, backend #3039) |
| Incidents | none; the thread deleted its own audit tick at the end | the account's ChatGPT plan lapsed mid-run, pausing the GPT lane; Actions billing refused CI for a while |

## What the trial did that the repo rules now carry

- Owners brought their stacks down before every report and named the slot (AGENTS.md, from #3085).
- Nothing reached staging, production or a live service; the live verifier signed in through the seeded 2FA flow on its own stack.
- The local gate ran on the pushed head and posted its statuses before the merge; `--check` was read before merging.
- CodeRabbit was waited for and read before merge-ready.
- Both PRs opened ready rather than as drafts, which cost one PR-checks run per push, about ten billed minutes each.

## What differed from the HzBook trial

- Verifiers ran on GPT, so no verdict came from the model that wrote the change; the diff audit on #3075 still found the one real gap.
- The owner on #3076 ran a trail review by GPT after its merge, which raised two flags it then closed; that review is the playbook's own step, not something the coordinator asked for.
- Two tickets instead of five, so the run shows the floor (28 minutes to a verified merge) rather than throughput.

## Verdict

Stock bstack took two small Snapcaster bugs to verified, merged PRs in 60 minutes with no question to Bryce, against roughly 2h50 per small ticket under the orchestrate/ coordinator on the day before.
The repo rules moved into AGENTS.md by #3085 were followed without being restated in the prompt.
Open questions remain the same as HzBook's: two runs merging at once, a crash mid-run, and the veto window agreed in the 2026-10-15 grilling, none of which this run exercised.
