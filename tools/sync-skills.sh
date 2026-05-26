#!/usr/bin/env bash
# sync-skills: pull Claude skills & agents from upstream GitHub repos listed in
# tools/skills-sources.json into .claude/skills/ and .claude/agents/.
#
# Declarative + reproducible: rerunning with no upstream changes is a no-op,
# the resolved commit + per-file blob SHA are written back to the lock block so
# two devs running the script land identically.
#
# Orphan deletion is scoped to the import surface (managed namespaces under
# .claude/skills/ and agent files previously recorded in the lock). Local
# skills like umbraco-* and usync-author are never touched.
#
# Usage:
#   bash tools/sync-skills.sh                  # full sync
#   bash tools/sync-skills.sh --check          # dry-run; exit 1 if any change pending
#   bash tools/sync-skills.sh --source <repo>  # limit to one source repo (e.g. antfu/skills)
#
# Honours $GITHUB_TOKEN for authenticated API calls. CI should always pass one.

set -euo pipefail

CONFIG="tools/skills-sources.json"
API="https://api.github.com"
RAW="https://raw.githubusercontent.com"

mode="sync"
filter_repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check)  mode="check"; shift ;;
    --source) filter_repo="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ ! -f "$CONFIG" ]; then
  echo "Config not found: $CONFIG" >&2
  exit 1
fi

for bin in jq curl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Required tool not found on PATH: $bin" >&2
    exit 1
  fi
done

curl_args=(-fsSL --retry 3 --retry-delay 2)
if [ -n "${GITHUB_TOKEN:-}" ]; then
  curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

jq '.lock' "$CONFIG" > "$TMPDIR/new_lock.json"

total_added=0
total_updated=0
total_unchanged=0
total_orphans=0
any_changes=0

src_count=$(jq '.sources | length' "$CONFIG")
for i in $(seq 0 $((src_count - 1))); do
  repo=$(jq -r ".sources[$i].repo" "$CONFIG")
  ref=$(jq -r ".sources[$i].ref" "$CONFIG")

  if [ -n "$filter_repo" ] && [ "$filter_repo" != "$repo" ]; then
    continue
  fi

  echo "sync-skills [$repo] resolving $ref ..."
  commit=$(curl "${curl_args[@]}" -H "Accept: application/vnd.github+json" \
    "$API/repos/$repo/commits/$ref" | jq -r .sha)

  echo "sync-skills [$repo] fetching tree @ ${commit:0:7} ..."
  tree_file="$TMPDIR/tree_$i.json"
  curl "${curl_args[@]}" -H "Accept: application/vnd.github+json" \
    "$API/repos/$repo/git/trees/$commit?recursive=1" > "$tree_file"

  if [ "$(jq -r '.truncated' "$tree_file")" = "true" ]; then
    echo "warning: tree truncated for $repo@$commit — large repo; some files may be missed" >&2
  fi

  includes_file="$TMPDIR/includes_$i.json"
  jq ".sources[$i].includes" "$CONFIG" > "$includes_file"

  # jq on Windows opens stdout in text mode and translates LF→CRLF when stdout
  # is redirected to a file; pipe through tr to strip CRs so target paths and
  # blob SHAs read cleanly later. (Pipes don't get the translation, only files.)
  triples_file="$TMPDIR/triples_$i.tsv"
  jq -r --slurpfile inc "$includes_file" '
    def should_ignore($p):
      ($p | endswith("/plugin.json")) or
      ($p | endswith("/README.md")) or
      ($p == "README.md") or
      ($p | endswith("/lsp.json")) or
      (($p | split("/") | last) | startswith("LICENSE")) or
      ($p | test("(^|/)\\.github(/|$)"));

    def map_target($entry; $i):
      if $i.kind == "plugin" then
        ($entry.path | ltrimstr($i.path + "/")) as $rel
        | if ($rel | startswith("skills/")) then
            ".claude/skills/" + $i.namespace + "/" + ($rel | ltrimstr("skills/"))
          elif ($rel | startswith("agents/")) then
            ($rel | ltrimstr("agents/")) as $agent
            | if ($agent | contains("/")) then null
              elif ($agent | endswith(".agent.md")) then
                ".claude/agents/" + ($agent | sub("\\.agent\\.md$"; ".md"))
              elif ($agent | endswith(".md")) then
                ".claude/agents/" + $agent
              else null end
          else null end
      elif $i.kind == "skill" then
        ($i.path | split("/") | last) as $leaf
        | if ($entry.path == $i.path) then
            ".claude/skills/" + $i.namespace + "/" + $leaf
          elif ($entry.path | startswith($i.path + "/")) then
            ".claude/skills/" + $i.namespace + "/" + $leaf + "/" + ($entry.path | ltrimstr($i.path + "/"))
          else null end
      elif $i.kind == "agent" then
        if ($entry.path == $i.path) then
          ($entry.path | split("/") | last) as $name
          | ".claude/agents/" + ($name | sub("\\.agent\\.md$"; ".md"))
        else null end
      else null end;

    .tree[]
    | select(.type == "blob")
    | select(should_ignore(.path) | not)
    | . as $entry
    | $inc[0][] as $matched
    | select(($entry.path == $matched.path) or ($entry.path | startswith($matched.path + "/")))
    | map_target($entry; $matched) as $tgt
    | select($tgt != null)
    | [$entry.path, $entry.sha, $tgt] | @tsv
  ' "$tree_file" | tr -d '\r' > "$triples_file"

  old_files_file="$TMPDIR/old_files_$i.json"
  jq --arg repo "$repo" '.[$repo].files // {}' "$TMPDIR/new_lock.json" > "$old_files_file"

  new_files_file="$TMPDIR/new_files_$i.json"
  jq -Rs '
    split("\n")
    | map(select(. != "") | split("\t"))
    | map({(.[0]): {blob: .[1], target: .[2]}})
    | add // {}
  ' "$triples_file" > "$new_files_file"

  added=0; updated=0; unchanged=0
  while IFS=$'\t' read -r upstream blob target; do
    [ -z "$upstream" ] && continue
    old_blob=$(jq -r --arg p "$upstream" '.[$p].blob // ""' "$old_files_file")
    if [ "$old_blob" = "$blob" ] && [ -f "$target" ]; then
      unchanged=$((unchanged + 1))
      continue
    fi
    if [ "$mode" = "sync" ]; then
      mkdir -p "$(dirname "$target")"
      curl "${curl_args[@]}" -o "$target" "$RAW/$repo/$commit/$upstream"
    fi
    if [ -z "$old_blob" ]; then
      added=$((added + 1))
    else
      updated=$((updated + 1))
    fi
    any_changes=1
  done < "$triples_file"

  orphans=0
  while IFS= read -r old_target; do
    [ -z "$old_target" ] && continue
    found=$(jq -r --arg t "$old_target" 'to_entries | map(select(.value.target == $t)) | length' "$new_files_file")
    if [ "$found" = "0" ]; then
      if [ "$mode" = "sync" ] && [ -f "$old_target" ]; then
        rm -f "$old_target"
      fi
      orphans=$((orphans + 1))
      any_changes=1
    fi
  done < <(jq -r 'to_entries[] | .value.target // empty' "$old_files_file" | tr -d '\r')

  if [ "$mode" = "sync" ]; then
    jq --arg repo "$repo" --arg ref "$ref" --arg commit "$commit" --slurpfile files "$new_files_file" \
      '.[$repo] = {ref: $ref, commit: $commit, files: $files[0]}' \
      "$TMPDIR/new_lock.json" > "$TMPDIR/new_lock.next.json"
    mv "$TMPDIR/new_lock.next.json" "$TMPDIR/new_lock.json"
  fi

  echo "sync-skills [$repo@${commit:0:7}]: +$added ~$updated -$orphans (=$unchanged unchanged)"
  total_added=$((total_added + added))
  total_updated=$((total_updated + updated))
  total_unchanged=$((total_unchanged + unchanged))
  total_orphans=$((total_orphans + orphans))
done

if [ "$mode" = "sync" ] && [ -d ".claude/skills" ]; then
  find .claude/skills -type d -empty -delete 2>/dev/null || true
fi

if [ "$mode" = "sync" ]; then
  jq --slurpfile lock "$TMPDIR/new_lock.json" '.lock = $lock[0]' "$CONFIG" > "$TMPDIR/config.next.json"
  mv "$TMPDIR/config.next.json" "$CONFIG"
fi

echo "sync-skills: total +$total_added ~$total_updated -$total_orphans (=$total_unchanged unchanged)"

if [ "$mode" = "check" ] && [ "$any_changes" -ne 0 ]; then
  exit 1
fi
