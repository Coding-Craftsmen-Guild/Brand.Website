---
name: usync-author
description: Author or modify code-first Umbraco DocumentTypes (ContentTypes) and Dictionary entries as raw uSync .config XML files. Enforces GUID uniqueness across the repo before assigning a key. Use when adding a new DocumentType or Dictionary entry, renaming one, or editing the schema of an existing code-first item.
---

# usync-author

Authoring rules for code-first uSync items in this repo. Read `## uSync` in [CLAUDE.md](../../../CLAUDE.md) first — it has the env split (dev = code-first, prod = capture-all) and the gitignore rules. This skill assumes that context.

## Scope

This skill covers two handler outputs that are **gitignored and code-first** in dev:

- `Brand.Web/uSync/v17/ContentTypes/` — DocumentTypes (handler alias `ContentTypeHandler`)
- `Brand.Web/uSync/v17/Dictionary/` — Dictionary entries (handler alias `DictionaryHandler`)

Everything else in `Brand.Web/uSync/v17/` (DataTypes, Languages, MediaTypes, MemberTypes, RelationTypes, Templates) is round-tripped through the backoffice and is **not** in scope for this skill — edit those via the Umbraco UI and let uSync auto-export.

## File format

Raw uSync v17 `.config` files — XML, one item per file. Top-level element carries `Key="<lowercase-guid>"` and `Alias="<aliasName>"`. Filenames are readable (the dev config sets `GuidNames: false`), flat in the handler folder (`UseFlatStructure: true`).

## Workflow

1. Author the source file(s) in the sibling source folder — **layout TBD, see TODO below**.
2. Run `mise run usync:bundle` to merge the source into `Brand.Web/uSync/v17/ContentTypes/` or `…/Dictionary/`.
3. Restart the dev container (`docker compose restart web`) so uSync's startup import applies the change to the DB.
4. Verify in the backoffice at http://localhost:28080.

## GUID uniqueness — mandatory rule

A duplicate `Key` across uSync items causes silent overwrites on import. **Before assigning any GUID** to a new DocumentType or Dictionary entry, prove it is globally unique across the repo.

### Procedure

1. Generate a candidate v4 GUID, lowercase, dashed, no braces:
   - PowerShell: `[guid]::NewGuid().ToString().ToLower()`
   - Node: `require('node:crypto').randomUUID()`
   - Web: any v4 generator → manually lowercase
2. Check uniqueness across **every** `.config` file in the repo:
   ```bash
   grep -rl --include="*.config" "<candidate-guid>" Brand.Web/uSync/ <sibling-source-folder>/
   ```
   (Once the sibling source folder exists, include it in the search path. Until then, search `Brand.Web/uSync/` alone.)
3. If grep returns any path: **discard the candidate**, generate a new one, repeat. Do not edit or partially reuse it.
4. If grep is silent: the GUID is safe. Use it as the `Key` attribute.

### Common mistakes to avoid

- **Don't copy a GUID** from a similar item to "save time." Every item needs its own.
- **Don't truncate or hand-edit** GUIDs to make them "look related." Format must be a real v4.
- **Don't reuse a GUID across types** (e.g., the same key on a DocumentType and a Dictionary entry). uSync's key space is global per handler set.
- **Don't skip the uniqueness check** even for "obviously new" items. The check is cheap; a silent overwrite isn't.

## Authoring guidance

The exact source-folder layout and the canonical shape of a DocumentType / Dictionary entry source file are not defined in this skill yet. Add them here when the framework lands. Until then:

### TODO — sibling source folder layout

User-defined. Candidates discussed but not chosen: `Brand.Web/Schema/`, `Brand.Web/uSync.Source/`, `Brand.Web/CodeFirst/`. Update this section with the agreed path, the per-handler subfolder structure, and the file-naming convention.

### TODO — DocumentType composition / inheritance pattern

How parent types, compositions, and tab/group layout are expressed in source. Derive from the first real examples once they exist, then encode the pattern here.

### TODO — Dictionary i18n file layout

Per-key (one file with all language values nested) vs per-language (one file per culture, all keys). uSync's native shape is per-key. Confirm and document.

## When to invoke this skill

- User asks to add, rename, or delete a DocumentType.
- User asks to add a new Dictionary entry or a new translation for an existing key.
- User is editing files under `Brand.Web/uSync/v17/ContentTypes/` or `…/Dictionary/` (gitignored; sources live elsewhere).
- User asks about how DocumentTypes or Dictionary entries are organized in this repo.

## When NOT to invoke this skill

- User wants to edit DataTypes, Languages, MediaTypes, MemberTypes, RelationTypes, or Templates — those are backoffice-driven, not code-first. Direct them to the Umbraco UI and let the export-on-save handle the file.
- Production capture / replication work — that's an ops concern, not authoring.
