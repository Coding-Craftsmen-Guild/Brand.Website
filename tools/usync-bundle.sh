#!/usr/bin/env bash
# usync-bundle: merge code-first DocumentType + Dictionary sources into
# Brand.Web/uSync/v17/ContentTypes/ and Brand.Web/uSync/v17/Dictionary/ so
# uSync's startup import can apply them. Outputs are gitignored.
#
# STUB — the sibling source folder layout is not defined yet. Fill in:
#   1. SOURCE_ROOT below
#   2. Subfolder mapping (source layout -> handler folder)
#   3. Any source-format transform (currently expects 1:1 copy of .config XML)

set -euo pipefail

SOURCE_ROOT=""

if [[ -z "$SOURCE_ROOT" ]]; then
  cat >&2 <<'EOF'
usync:bundle is not implemented yet — the sibling source layout is undefined.
Decide on the folder (candidates: Brand.Web/Schema/, Brand.Web/uSync.Source/,
Brand.Web/CodeFirst/), then set SOURCE_ROOT in tools/usync-bundle.sh and
fill in the copy step. See .claude/skills/usync-author/SKILL.md for context.
EOF
  exit 1
fi
