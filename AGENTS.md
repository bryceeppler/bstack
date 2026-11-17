# bstack contributor guide

This repo is [pstack](https://github.com/cursor/plugins/tree/main/pstack) by Lauren Tan, adapted to T3 Code for Claude Code and Codex threads. `UPSTREAM` pins the upstream commit it matches.

Before you edit anything under `skills/`, read [T3-NATIVE.md](./T3-NATIVE.md) in full. It is the translation contract: which Cursor mechanism becomes which T3 mechanism, how skills reference each other, where skills and the model config live, and the definition of done.

## Rules

- Keep upstream wording wherever it is harness-neutral. Change only what names a Cursor mechanism.
- Upstream names stay: `poteto-mode`, `poteto-help`, `setup-pstack`, role names, playbook names.
- `node scripts/check-t3-native.mjs` must exit 0. Pass skill names to check a subset.
- A delegated worker writes only the files its brief names and runs no git commands.

## Syncing upstream

bstack syncs straight from `cursor/plugins`.
Nothing comes from another T3 port.

1. Run `scripts/sync-upstream.sh` on a clean branch.
   It builds two commits from upstream's `pstack/`, one at the `sha` in `UPSTREAM` and one at upstream's head, and cherry-picks the second onto the branch.
   Git merges every change that does not touch translated or bstack text, and bumps `sha` in the same commit.
2. Resolve each conflict through T3-NATIVE.md.
   A conflict in a file bstack deleted stays deleted.
   Where upstream rewrote a passage, take its text, translate it, and put back only the bstack rules T3-NATIVE.md names.
   Keep upstream's line layout in skill text, because a reflowed paragraph conflicts on every later sync.
3. Read the merged diff too.
   A change git merged cleanly can still name a Cursor mechanism the checker has no rule for.
4. Run the checker, then `git cherry-pick --continue`.

Pass a commit to sync to that commit instead of upstream's head.
