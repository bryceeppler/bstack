# bstack trial: stock Autopilot against the orchestrate/ coordinator

Trial: T3 thread `mcp:cf34a185-ecef-416e-b113-c503dbc074d3`, stock bstack `/poteto-mode` Autopilot-full, launched 2026-10-15 06:06 UTC on HzBook #972, #976, #985 (small) and #977, #978 (standard), the public booking cluster.
Comparison run: `2026-10-14-schedule-and-booking` under the orchestrate/ coordinator, launched 2026-10-14 11:16 UTC on #923, #940 (small) and #921, #934, #941 (standard), the same product area, one day earlier.
The two runs took different tickets on different days, and the comparison run hit a GitHub Actions billing stop mid-run, so read the numbers as one data point each, not a controlled test.

## Numbers

| | bstack trial (5 issues) | orchestrate/ run (5 issues) |
|---|---|---|
| Launch to code-ready, per unit | 33, 35, 38, 44, 79 min | 39 min, 3h21, 3h21, 4h02, 7h40 |
| Launch to merged, per unit | 44, 46, 67, 122, 161 min | 1h39, 5h16, 5h30, 6h09, 7h40 |
| Whole run, launch to last merge | 2 h 41 min | 7 h 40 min |
| Time waiting on Bryce | 0 | about 1 to 2 h per merge (merge-ready to merged: 2h09, 2h07, 1h55, 1h00, 0) |
| Questions to Bryce (gates) | 0 | 6 (4 merge approvals, 1 extra round, 1 billing) |
| Rounds per unit | 1, 1, 2, 2, 2 | 1, 1, 1, 2, 4 (one granted past the cap) |
| Checker verdicts | 16 | 19 |
| Verdicts with in-scope findings | 5 of 16 | 2 of 19 |
| In-scope findings fixed before merge | 14 (#985: 1, #978: 7, #977: 6) | about 4 |
| Follow-up bugs on main found and filed | 7 (#1002 to #1008), filed on Bryce's "yes" | 4 |
| Coordinator turns | 44 (about 16 per hour) | not in the pack |
| Staging after each merge | green, 4 of 4 settled (5th running at the last check) | green, 5 of 5 |
| Incidents | an owner misread a failed conflict check as clean, caught by the coordinator; #977's first local gate failed 3 browser tests on an untyped stub, fixed by its owner before reporting | Actions billing refused CI mid-run; one unit needed a fourth round for a rebase over a sibling |

Checker lanes in the trial: a live drive on every unit, a GPT review on every unit, and an Opus review on the two standard units, which is the same shape as the orchestrate/ profile's lanes.
Both of the trial's merge-blocking findings on the small and standard pages were the same kind: a fix with no test on the page itself, caught by the GPT lane on #985 and #977 and by both lanes on #985.

## What the trial did without being told

- It opened draft PRs and marked them ready at code-ready, and it ran `pnpm gate:local` on the exact head before every report, although pstack's own rule is to open PRs ready.
  HzBook's repo instructions and Bryce's global rules carried that, so the CI-cost rule held with no bstack change.
- It sequenced the two overlapping units (#977 then #978), held #978's post-fix check until #977 merged so one rebase got one check, and checked main's movement by hand before each merge.
- Owners confirmed the verified head before merging, stopped their servers and browser sessions, and reported "stopping" with the merge commit.
- It corrected itself on filing follow-ups (Bryce's rule: no tickets unless asked) and asked first.
- Its audit tick ran every 30 minutes and found nothing stuck in 5 ticks; no owner stalled.

## What our scripts would have added, judged against what happened

- `merge-ready.mjs` and the approval rows: not needed in this run, since Bryce had granted merges in the prompt and the owners checked the head themselves.
  They matter only if Bryce takes merge authority back, or if two runs merge at once.
- `main.mjs` main lock: not exercised, one run.
- The chief of staff: Bryce asked the trial thread for status twice and got plain answers; nothing was lost by talking to the run directly.
- `liveness.mjs`, the watcher, the heartbeat: nothing stalled and nothing was missed; the audit tick alone carried the run.

## Verdict

Stock bstack took five tickets from the same area to merged, verified PRs in 2 h 41 min with no question to Bryce, found more in-scope defects per verdict than the orchestrate/ run, and surfaced seven follow-up bugs.
Nothing in the run needed the orchestrate/ coordinator's scripts, and HzBook's repo rules carried the policies (drafts, local gate, no real accounts, no tickets unless asked) that the coordinator's prose used to carry.
The open questions are the ones one run cannot answer: two runs merging at once (the main lock), a usage-limit or T3 outage mid-run (restart), and away-mode gates, none of which occurred here.
