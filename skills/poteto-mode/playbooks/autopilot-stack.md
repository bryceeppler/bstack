### Autopilot-stack

**You own the stack, never the landing.**
**Hand the operator one linear `gh stack` of verified PRs to review and land.**
**Autopilot-full** holds except for how verified work leaves.
Each tick re-reads both playbooks from the installed copy (`<poteto-mode dir>/playbooks/`, refreshed by `npx skills update -g`), and this one wins where they differ.

1. **Run Autopilot-full's owners, with the stack in place of the run branch.**
   Owners report STACK-READY in place of landing-ready.
   They never rebase onto another branch, trunk included, and never open, merge or close a PR, or arm auto-merge, because the root owns the chain's topology and the operator owns the landing.
   When an item depends on another, its owner branches from that item's branch, not from trunk.
2. **Give the topology one writer.**
   Owners push only their own branches and report each tip and its intended parent.
   Only you change the chain, with `gh stack` per the `gh-stack` skill.
   Add each clean item in dependency order as the next layer.
   The bottom PR opens ready, and every layer above stays a draft until the one below merges.
   An owner takes your push as its new base and lease, and on a conflict resolves its own slice for you to push.
3. **Absorb drift at the root.**
   Until landing starts, apply Autopilot-full step 7's trunk test to the bottom and restack the chain where it calls for one.
   Then apply the patch-id rule link by link, since a link's base is its parent.
4. **Deliver the chain, then keep your hands off it.**
   Each link carries its verdict in its PR.
   Once landing starts, nobody writes to the chain except the post-merge restack that `playbooks/shipping.md` sanctions, because a second writer breaks a landing in flight.
   A mid-landing problem goes through you to the operator, and any fix waits for the operator's go.
   At handoff, clear any watch you armed with `unwatch_pull_request`.

**Choosing between the autopilots.**
Autopilot-full when the issues can merge together and landing authority is granted.
Autopilot-stack when each change needs the operator's review before the next can proceed, or merge authority is withheld.

**Reply:** catch the operator up per the **ketchup** skill, with links to the stack root and tip, a one-line verdict per link, and anything parked or excluded with the reason.
