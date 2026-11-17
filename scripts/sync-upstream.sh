#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit

usage="usage: scripts/sync-upstream.sh [<upstream commit>]

Three-way merges upstream pstack into this checkout: base is the commit pinned
in UPSTREAM, theirs is <upstream commit> (default: upstream's default branch).
Stops on conflicts like any cherry-pick. Resolve them through T3-NATIVE.md,
then run git cherry-pick --continue."

[ "${1:-}" != "-h" ] && [ "${1:-}" != "--help" ] || { echo "$usage"; exit 0; }

root=$(git rev-parse --show-toplevel)
pin="$root/UPSTREAM"
not_ported=(.cursor-plugin plugin.json assets automations docs)

pinned() { sed -n "s/^$1=//p" "$pin"; }
repo=$(pinned repo)
path=$(pinned path)
bundle=$(pinned bundle)
old=$(pinned sha)

[ -z "$(git -C "$root" status --porcelain)" ] || { echo "commit or discard local changes first" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git clone -q --filter=blob:none --no-checkout "$repo" "$work/src"
git -C "$work/src" sparse-checkout set "$path" "$bundle"
new=$(git -C "$work/src" rev-parse --verify "${1:-origin/HEAD}^{commit}")

[ "$new" != "$old" ] || { echo "already at ${old:0:7}"; exit 0; }
git -C "$work/src" merge-base --is-ancestor "$old" "$new" || { echo "$new does not descend from the pinned $old" >&2; exit 1; }

snapshot() {
  local sha=$1 tree="$work/tree-$1"
  git -C "$work/src" checkout -q "$sha"
  mkdir -p "$tree/skills"
  cp -a "$work/src/$path/." "$tree/"
  cp -a "$work/src/$bundle" "$tree/skills/"
  (cd "$tree" && rm -rf "${not_ported[@]}")
  sed "s/^sha=.*/sha=$sha/" "$pin" > "$tree/UPSTREAM"
  GIT_INDEX_FILE="$work/index-$sha" git -C "$root" --work-tree="$tree" add -f -A
  GIT_INDEX_FILE="$work/index-$sha" git -C "$root" write-tree
}

old_tree=$(snapshot "$old")
new_tree=$(snapshot "$new")
base=$(git -C "$root" commit-tree "$old_tree" -m "pstack@$old")
tip=$(git -C "$root" commit-tree "$new_tree" -p "$base" \
  -m "sync upstream pstack ${old:0:7}..${new:0:7}" \
  -m "$(git -C "$work/src" log --format='%h %s' "$old..$new" -- "$path" "$bundle")")

git -C "$root" cherry-pick "$tip"
