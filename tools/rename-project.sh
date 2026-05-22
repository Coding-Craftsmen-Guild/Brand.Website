#!/usr/bin/env bash
# Rename the "Brand" placeholder to a real name across the repo.
# Usage: mise run rename-project <NewName>
# Example: mise run rename-project Acme.Site
#
# Replaces `Brand.Web` -> `<NewName>.Web` and `brand.web` -> `<newname>.web`
# in tracked text files, then renames the folder and .csproj. Skips this tool
# directory so it cannot rewrite itself.

set -euo pipefail

OLD_PASCAL="Brand.Web"
OLD_LOWER="brand.web"

new_name="${1:-}"

if [ -z "$new_name" ]; then
  echo "Usage: mise run rename-project <NewName>" >&2
  echo "Example: mise run rename-project Acme.Site" >&2
  exit 1
fi

if ! printf '%s' "$new_name" | grep -Eq '^[A-Za-z][A-Za-z0-9.]*[A-Za-z0-9]$'; then
  echo "Invalid name '$new_name'. Use letters, digits, and dots; start with a letter." >&2
  exit 1
fi

if [ "$new_name" = "Brand" ]; then
  echo "Name is already 'Brand' — nothing to do."
  exit 0
fi

new_pascal="${new_name}.Web"
new_lower="$(printf '%s' "$new_name" | tr '[:upper:]' '[:lower:]').web"

if [ ! -d "$OLD_PASCAL" ]; then
  echo "Could not find ${OLD_PASCAL}/ in $(pwd). Already renamed?" >&2
  exit 1
fi

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

rm -rf "${new_pascal}/bin" "${new_pascal}/obj"
echo "cleaned  ${new_pascal}/bin/ and ${new_pascal}/obj/"

echo
echo "Done. ${touched} file(s) updated."
echo "Next: mise run restore && mise run build"
