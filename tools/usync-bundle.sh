#!/usr/bin/env bash
# usync-bundle: merge code-first DocumentType (and later Dictionary) sources
# from Brand.Core/ into Brand.Web/uSync/v17/ContentTypes/ so uSync's startup
# import picks them up. Bundle output is gitignored; the .config files under
# Brand.Core are the source of truth.
#
# Source layout: any .config under Brand.Core/{Components,Compositions,Pages}/**
# is bundled. Filenames are flat-copied (uSync uses flat structure for the
# handler folder).

set -euo pipefail

SOURCE_ROOT="Brand.Core"
TARGET="Brand.Web/uSync/v17/ContentTypes"

mkdir -p "$TARGET"

# Clean slate so deletes in source actually propagate.
find "$TARGET" -maxdepth 1 -type f -name "*.config" -delete

# Flat copy every .config under the source tree, excluding build output.
count=0
while IFS= read -r -d '' file; do
  cp "$file" "$TARGET/"
  count=$((count + 1))
done < <(find "$SOURCE_ROOT" -type f -name "*.config" \
           -not -path "*/bin/*" -not -path "*/obj/*" \
           -print0)

echo "usync:bundle copied $count file(s) -> $TARGET"
