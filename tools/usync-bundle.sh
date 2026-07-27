#!/usr/bin/env bash
# usync-bundle: merge code-first sources from Brand.Core/ into Brand.Web/uSync/v17/
# so uSync's startup import picks them up. Bundle output is gitignored; the .config
# files under Brand.Core are the source of truth.
#
# Routing is by folder: any .config under a Dictionary/ folder
# (Brand.Core/**/Dictionary/*.config) is a uSync Dictionary item and goes to
# Dictionary/; every other .config is a DocumentType and goes to ContentTypes/.
# Filenames are flat-copied (uSync uses flat structure for handler folders).

set -euo pipefail

SOURCE_ROOT="Brand.Core"
CONTENT_TYPES_TARGET="Brand.Web/uSync/v17/ContentTypes"
DICTIONARY_TARGET="Brand.Web/uSync/v17/Dictionary"

mkdir -p "$CONTENT_TYPES_TARGET" "$DICTIONARY_TARGET"

# Clean slate so deletes in source actually propagate (both targets).
find "$CONTENT_TYPES_TARGET" -maxdepth 1 -type f -name "*.config" -delete
find "$DICTIONARY_TARGET" -maxdepth 1 -type f -name "*.config" -delete

# Flat copy every .config under the source tree, routing by folder, excluding build output.
content_count=0
dict_count=0
while IFS= read -r -d '' file; do
  case "$file" in
    */Dictionary/*)
      cp "$file" "$DICTIONARY_TARGET/"
      dict_count=$((dict_count + 1))
      ;;
    *)
      cp "$file" "$CONTENT_TYPES_TARGET/"
      content_count=$((content_count + 1))
      ;;
  esac
done < <(find "$SOURCE_ROOT" -type f -name "*.config" \
           -not -path "*/bin/*" -not -path "*/obj/*" \
           -print0)

echo "usync:bundle copied $content_count content-type file(s) -> $CONTENT_TYPES_TARGET"
echo "usync:bundle copied $dict_count dictionary file(s) -> $DICTIONARY_TARGET"
