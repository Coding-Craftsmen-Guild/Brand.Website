#!/usr/bin/env bash
# Clone this template into a new directory and rename the "Brand" placeholder.
# Usage: mise run clone-project <NewName> <DestinationPath>
# Example: mise run clone-project Acme.Site ../acme-site
#
# 1. Copies tracked files (`git archive HEAD`) into <DestinationPath> — no
#    .git, no bin/obj/node_modules, no runtime data.
# 2. Rewrites `Brand.Web` -> `<NewName>.Web` and `brand.web` -> `<newname>.web`
#    in tracked text files inside the destination, then renames the folder
#    and .csproj. Skips the tools/ directory so it cannot rewrite itself.
# 3. Initialises a fresh git repo at the destination (no commit — review
#    and commit yourself).

set -euo pipefail

OLD_PASCAL="Brand.Web"
OLD_LOWER="brand.web"

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

if [ ! -d "$OLD_PASCAL" ]; then
  echo "Could not find ${OLD_PASCAL}/ in $(pwd). Run this from the template repo root." >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git work tree. clone-project uses 'git archive HEAD' to copy files." >&2
  exit 1
fi

new_pascal="${new_name}.Web"
new_lower="$(printf '%s' "$new_name" | tr '[:upper:]' '[:lower:]').web"

mkdir -p "$dest"
git archive HEAD | tar -x -C "$dest"
echo "copied   tracked files -> ${dest}/"

cd "$dest"

touched=0
while IFS= read -r -d '' f; do
  if grep -qE "${OLD_PASCAL}|${OLD_LOWER}" "$f"; then
    sed -i.bak \
      -e "s|${OLD_PASCAL}|${new_pascal}|g" \
      -e "s|${OLD_LOWER}|${new_lower}|g" \
      "$f"
    rm -f "${f}.bak"
    echo "updated  ${f#./}"
    touched=$((touched + 1))
  fi
done < <(
  find . \
    -type d \( \
      -name .git -o -name bin -o -name obj -o -name data \
      -o -name node_modules -o -name tools \
      -o -name .vs -o -name .vscode -o -name .idea \
    \) -prune -o \
    -type f \( \
      -name '*.cs' -o -name '*.csproj' -o -name '*.props' -o -name '*.targets' \
      -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' -o -name '*.toml' \
      -o -name '*.md' -o -name '*.sh' -o -name '*.ps1' -o -name '*.cshtml' \
      -o -name '*.razor' -o -name '*.sln' \
      -o -name 'Dockerfile' -o -name '.gitignore' -o -name '.dockerignore' \
      -o -name '.gitattributes' -o -name '.editorconfig' \
    \) -print0
)

mv "$OLD_PASCAL" "$new_pascal"
echo "renamed  ${OLD_PASCAL}/ -> ${new_pascal}/"

if [ -f "${new_pascal}/${OLD_PASCAL}.csproj" ]; then
  mv "${new_pascal}/${OLD_PASCAL}.csproj" "${new_pascal}/${new_pascal}.csproj"
  echo "renamed  ${new_pascal}/${OLD_PASCAL}.csproj -> ${new_pascal}/${new_pascal}.csproj"
fi

git init -q
echo "git init in $(pwd)"

echo
echo "Done. ${touched} file(s) updated in ${dest}/."
echo "Next: cd ${dest} && mise install && mise run setup && mise run build"
