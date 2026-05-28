#!/usr/bin/env bash
# Clone this template into a new directory and rename every "Brand" / "brand"
# reference to a new project name. Greedy: covers every text file under the
# destination, not just *.cs / *.csproj.
#
# Usage: mise run clone-project <NewName> <DestinationPath>
# Example: mise run clone-project Acme.Site ../acme-site
#
# 1. Copies tracked files (`git archive HEAD`) into <DestinationPath> — no
#    .git, no bin/obj/node_modules, no runtime data.
# 2. Rewrites every Brand/brand form across all text files in the destination:
#      Brand.<X>     -> <NewName>.<X>           (Pascal, dot-qualified)
#      brand.<x>     -> <newname>.<x>           (lower,  dot-qualified)
#      Brand-<X>     -> <NewName-kebab>-<X>     (Pascal, kebab)
#      brand-<x>     -> <newname-kebab>-<x>     (lower,  kebab — Tailwind tokens, npm name)
#      bare 'Brand'  -> <NewName>               (catch-all Pascal)
#      bare 'brand'  -> <newname-kebab>         (catch-all lower)
#    Word boundaries (\b) prevent partial-word hits (brand_dirs, rebrand…).
#    Pruned dirs: .git, bin, obj, dist, node_modules, .vs, .vscode,
#    .idea, data, wshobson. Only this script (clone-project.sh) is excluded
#    by name so its literal "Brand" search patterns survive — other tools/
#    scripts (e.g. usync-bundle.sh, which hardcodes Brand.Core/Brand.Web
#    paths) DO get renamed. wshobson/ is vendored third-party Tailwind docs
#    that use 'brand' generically — leave alone.
# 3. Renames each Brand.<X>/ folder and its .csproj.
# 4. Initialises a fresh git repo at the destination (no commit — review
#    and commit yourself).

set -euo pipefail

new_name="${1:-}"
dest="${2:-}"

if [ -z "$new_name" ] || [ -z "$dest" ]; then
  echo "Usage: mise run clone-project <NewName> <DestinationPath>" >&2
  echo "Example: mise run clone-project Acme.Site ../acme-site" >&2
  exit 1
fi

if ! printf '%s' "$new_name" | grep -Eq '^[A-Za-z][A-Za-z0-9.]*[A-Za-z0-9]$'; then
  echo "Invalid name '$new_name'. Use letters, digits, and dots; start with a letter." >&2
  exit 1
fi

if [ "$new_name" = "Brand" ]; then
  echo "Name is already 'Brand' — pick a different name." >&2
  exit 1
fi

if [ -e "$dest" ]; then
  echo "Destination '$dest' already exists. Refusing to overwrite." >&2
  exit 1
fi

if ! ls -d Brand.* >/dev/null 2>&1; then
  echo "No Brand.* directories in $(pwd). Run this from the template repo root." >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git work tree. clone-project uses 'git archive HEAD' to copy files." >&2
  exit 1
fi

# --- 1. Copy --------------------------------------------------------------
mkdir -p "$dest"
git archive HEAD | tar -x -C "$dest"
echo "copied   tracked files -> ${dest}/"

cd "$dest"

# --- 2. Compute the six replacement forms --------------------------------
# new_name preserves the user's input casing (e.g. "Acme.Site").
new_pascal_dot="${new_name}"                                                 # Acme.Site
new_lower_dot="$(printf '%s' "$new_name" | tr '[:upper:]' '[:lower:]')"      # acme.site
new_pascal_kebab="$(printf '%s' "$new_name" | tr '.' '-')"                   # Acme-Site
new_lower_kebab="$(printf '%s' "$new_lower_dot" | tr '.' '-')"               # acme-site

# Sanity: lowercase kebab is what bare 'brand' becomes (CSS-friendly fallback).
echo "rename forms:"
echo "  Brand.<X>  -> ${new_pascal_dot}.<X>"
echo "  brand.<x>  -> ${new_lower_dot}.<x>"
echo "  brand-<x>  -> ${new_lower_kebab}-<x>"
echo "  bare Brand -> ${new_pascal_dot}"
echo "  bare brand -> ${new_lower_kebab}"

# --- 3. Find every text file containing 'brand' (case-insensitive) --------
# -I skips binary; --exclude-dir prunes build/runtime/tooling.
files=()
while IFS= read -r f; do
  files+=("$f")
done < <(grep -rIli 'brand' . \
  --exclude-dir=.git --exclude-dir=bin --exclude-dir=obj \
  --exclude-dir=node_modules --exclude-dir=dist \
  --exclude-dir=.vs --exclude-dir=.vscode \
  --exclude-dir=.idea --exclude-dir=data --exclude-dir=wshobson \
  --exclude=clone-project.sh)

# --- 4. Sed them all in one pass per file --------------------------------
# Order matters: specific (\.  and -) before catch-all (\b...\b).
touched=0
for f in "${files[@]}"; do
  sed -i.bak -E \
    -e "s|\\bBrand\\.|${new_pascal_dot}.|g" \
    -e "s|\\bbrand\\.|${new_lower_dot}.|g" \
    -e "s|\\bBrand-|${new_pascal_kebab}-|g" \
    -e "s|\\bbrand-|${new_lower_kebab}-|g" \
    -e "s|\\bBrand\\b|${new_pascal_dot}|g" \
    -e "s|\\bbrand\\b|${new_lower_kebab}|g" \
    "$f"
  rm -f "${f}.bak"
  echo "updated  ${f#./}"
  touched=$((touched + 1))
done

# --- 5. Rename Brand.<X>/ folders and their csproj files -----------------
brand_dirs=()
for d in Brand.*/; do
  [ -d "$d" ] || continue
  brand_dirs+=("${d%/}")
done

for old_pascal in "${brand_dirs[@]}"; do
  suffix="${old_pascal#Brand.}"
  new_pascal="${new_pascal_dot}.${suffix}"
  mv "$old_pascal" "$new_pascal"
  echo "renamed  ${old_pascal}/ -> ${new_pascal}/"
  if [ -f "${new_pascal}/${old_pascal}.csproj" ]; then
    mv "${new_pascal}/${old_pascal}.csproj" "${new_pascal}/${new_pascal}.csproj"
    echo "renamed  ${new_pascal}/${old_pascal}.csproj -> ${new_pascal}/${new_pascal}.csproj"
  fi
done

# --- 6. Fresh git repo ---------------------------------------------------
git init -q
echo "git init in $(pwd)"

echo
echo "Done. ${touched} file(s) updated in ${dest}/."
echo "Next: cd ${dest} && mise install && mise run setup && mise run build"
