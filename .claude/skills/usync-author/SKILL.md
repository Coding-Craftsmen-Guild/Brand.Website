---
name: usync-author
description: Author or modify code-first Umbraco DocumentTypes (ContentTypes) and Dictionary entries. Source files live under Brand.Core/{Components,Compositions,Pages} and bundle into Brand.Web/uSync/v17/. Enforces GUID uniqueness across the repo before assigning a key. Use when adding a new DocumentType or Dictionary entry, renaming one, or editing the schema of an existing code-first item.
---

# usync-author

Code-first authoring for Umbraco DocumentTypes (and Dictionary, TBD). Read `## uSync` in [CLAUDE.md](../../../CLAUDE.md) first for the env split (dev = code-first import-on-startup, prod = full-capture) and the gitignore rules.

## Source layout

DocumentType `.config` files live in `Brand.Core/`, organised by feature:

```
Brand.Core/
├── Components/      # IsElement=true types (block list items, etc.)
│   └── HomePage/    # grouped by the page that uses them
│       └── HeroBanner/
│           ├── herobannercomponent.config       <- uSync source
│           └── HeroBannerViewComponent.cs       <- optional ViewComponent + ViewModel
├── Compositions/    # IsElement=false reusable types (Header, Footer, GlobalSettings...)
│   ├── Header/
│   │   ├── header.config
│   │   └── HeaderViewComponent.cs
│   ├── Footer/
│   │   ├── footer.config
│   │   └── FooterViewComponent.cs
│   └── GlobalSettings/
│       └── globalsettings.config                <- no ViewComponent needed
└── Pages/           # IsElement=false page types (HomePage, Page...)
    ├── HomePage/
    │   └── homepage.config
    └── Page/
        └── page.config
```

Rules:
- One folder per doctype. Folder name in PascalCase; matches the human concept (e.g. `HeroBanner`), not the uSync alias.
- The `.config` filename matches what uSync writes: **lowercase, dot-config**. uSync flattens by alias-lowered (e.g. alias `heroBanner` → file `herobanner.config`). When you rename a doctype's alias, also rename the file.
- Co-located files (`*.cs`, future `*.cshtml`, etc.) are free — anything that helps a dev extend the doctype. The bundler only touches `*.config`.

## Bundle

`mise run usync:bundle` ([tools/usync-bundle.sh](../../../tools/usync-bundle.sh)) does:
1. `mkdir -p Brand.Web/uSync/v17/ContentTypes`
2. Wipe existing `*.config` in that folder (so source deletes propagate).
3. Flat-copy every `*.config` under `Brand.Core/` (excluding `bin/`, `obj/`) into the target.

Run the bundler whenever you add, rename, delete, or edit a `.config`. Then restart the dev container (`docker compose restart web`) so uSync's startup import applies the change. In dev, `SourceCodeAuto` ModelsBuilder regenerates the corresponding `.generated.cs` automatically — no extra step.

## ViewComponent pattern

Co-located ViewComponent + ViewModel record, Compositions-take-interface rule, and the `Models.X` namespace-shadow workaround all live in the [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md) skill.

## Renaming a doctype

Round-trip-tested procedure (Key-matched in uSync, SourceCodeAuto in MB cleans stale generated files automatically — observed in practice):

1. Edit `Brand.Core/<category>/<name>/<oldname>.config`: change `Alias=` and `<Name>`. Keep the `Key=` GUID untouched — that's the identity uSync matches on.
2. Rename the source file: `<oldname>.config` → `<newname>.config` (lowercased alias).
3. (Optional) rename the enclosing folder to match the new conceptual name.
4. **Leave any ViewComponent referencing the old generated class as-is for now.** It compiles against the stale generated file, which keeps the build green so the app can boot.
5. `mise run usync:bundle`.
6. `mise run dev`. Boot sequence: build passes → app starts → uSync sees the file with the matching Key → renames the doctype in DB → MB SourceCodeAuto fires → writes new `<NewName>.generated.cs` and removes `<OldName>.generated.cs`.
7. Update the ViewComponent (and any other consumers) to the new class name. dotnet watch picks up the change and rebuilds.

Do **not** rename or hand-edit `Brand.Core/Generated/*.generated.cs` to shortcut step 6 — see the rule in [CLAUDE.md](../../../CLAUDE.md) under `## Umbraco specifics`.

## Tab declarations — composition gotcha

A property in a `.config` references its tab via `<Tab Alias="...">Display Caption</Tab>`. **uSync's importer resolves that reference against the doctype's own `<Tabs>` element only — composition inheritance does NOT apply at the serializer level**, even though Umbraco's backoffice UI does merge tabs across compositions by alias.

If a property references a tab that isn't declared on the same doctype, uSync logs `Unable to find tab "<alias>" it doesn't seem to exist on the content type` (a warning, not an error) and **silently drops the property** during import. The doctype imports otherwise fine — the missing property is easy to miss.

### Pre-flight check when adding a property to an existing doctype

1. Find every `<Tab Alias="X">` reference in your new property block.
2. Confirm a matching `<Tab><Alias>X</Alias>…</Tab>` exists inside the `<Tabs>` element of the **same** `.config`. Not the composition's `.config` — the doctype's own.
3. If the tab is missing locally but exists on a composition (typical for `content` tab declared on a Page composition):
   - Add the `<Tab>` block to this doctype's `<Tabs>` element too.
   - Use a **new unique GUID** for the tab `<Key>` (follow the GUID-uniqueness rule below). The composition's tab and this one share the alias, so the backoffice merges them visually into one tab.
4. If `<Tabs />` is empty on the doctype, replace it with `<Tabs><Tab>…</Tab></Tabs>`.

The Components-on-HomePage round-trip (2026-05) hit exactly this — HomePage referenced the `content` tab inherited from Page composition, but didn't declare it locally, so uSync dropped the property silently. See [Brand.Core/Pages/HomePage/homepage.config](../../../Brand.Core/Pages/HomePage/homepage.config) for the resolved shape.

## GUID uniqueness — mandatory rule

A duplicate `Key` across uSync items causes silent overwrites on import. **Before assigning any GUID** to a new DocumentType (and later Dictionary entry), prove it is globally unique across the repo.

### Procedure

1. Generate a candidate v4 GUID, lowercase, dashed, no braces:
   - PowerShell: `[guid]::NewGuid().ToString().ToLower()`
   - Node: `require('node:crypto').randomUUID()`
2. Check uniqueness across **every** `.config` file in the repo:
   ```bash
   grep -rl --include="*.config" "<candidate-guid>" Brand.Core/ Brand.Web/uSync/
   ```
3. If grep returns any path: **discard the candidate**, generate a new one, repeat. Do not edit or partially reuse it.
4. If grep is silent: the GUID is safe. Use it as the `Key` attribute on the root `<ContentType ...>` element (and any nested `<GenericProperty><Key>...</Key>` elements — every property needs its own unique key too).

### Common mistakes to avoid

- **Don't copy a GUID** from a similar item to "save time."
- **Don't truncate or hand-edit** GUIDs to make them "look related." Must be a real v4.
- **Don't reuse a GUID across items** (different types share the global namespace).
- **Don't skip the check** even for "obviously new" items. The check is cheap; a silent overwrite isn't.

## Scope

In scope:
- `Brand.Core/Components/**/*.config` — element types
- `Brand.Core/Compositions/**/*.config` — reusable mixins
- `Brand.Core/Pages/**/*.config` — page types

**Out of scope** (use the Umbraco backoffice, let uSync auto-export to `Brand.Web/uSync/v17/<handler>/`):
- DataTypes, Languages, MediaTypes, MemberTypes, RelationTypes, Templates — backoffice-driven, source-tracked.
- Backoffice DocumentType experimentation — if you want a doctype quickly, create it in backoffice and use the dashboard's manual Export to inspect the `.config`. Move the file into `Brand.Core/<category>/<name>/` to make it the source of truth, then delete the backoffice version + re-bundle.

## See also

- [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md) — render layer (ViewComponent + ViewModel, Razor partials, `Models.X` workaround).
- [umbraco-datatypes](../umbraco-datatypes/SKILL.md) — picking the `<Definition>` GUID for a property, when to reuse vs create.
- [umbraco-blocks](../umbraco-blocks/SKILL.md) — Block List / Grid / single composition from IsElement doctypes.

Dictionary i18n layout is still open — see `## Open questions` in [CLAUDE.md](../../../CLAUDE.md).

## When to invoke this skill

- User asks to add, rename, or delete a DocumentType.
- User is editing a `.config` under `Brand.Core/{Components,Compositions,Pages}/`.
- User asks about doctype organisation, the bundler, or where a new doctype should live.

## When NOT to invoke this skill

- User wants to edit DataTypes, Languages, MediaTypes, MemberTypes, RelationTypes, or Templates — backoffice-driven.
- Production capture / replication — an ops concern, not authoring.
