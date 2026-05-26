---
name: umbraco-blocks
description: Compose Umbraco block editors (Block List, Block Grid, single-block) from IsElement DocumentTypes and route them to ViewComponents via the partials in Brand.Web/Views/Partials/. Use when adding a new block to a page, deciding between Block List / Block Grid / single, or wiring a new IsElement type into render dispatch.
---

# umbraco-blocks

Connect three things into a working block: an `IsElement=true` DocumentType (the block's schema), a Block editor DataType (the picker shown to editors), and a render path (ViewComponent or partial). Each side is owned by another skill — this skill covers the seams.

## Block editor choice

| Editor | When |
|---|---|
| **Block List** (`Umbraco.BlockList`) | Ordered, single-column sequence. Each block stands alone. Default choice for page sections. Used today on HomePage `components`. |
| **Block Grid** (`Umbraco.BlockGrid`) | Editor needs to control layout — widths, columns, nested areas. Use when the editor's intent is "lay out two columns" not just "add a section". |
| **Single Block** (`Umbraco.BlockList` configured to allow one) | One-of slots — e.g. "Hero" at top of page where only one hero ever exists. Cheap to upgrade to a list later. |

Don't pick Block Grid for purely sequential content — the layout knobs become noise.

## Anatomy of a block

A working block has four pieces:

1. **IsElement DocumentType** under [Brand.Core/Components/](../../../Brand.Core/Components/)`<Page>/<Name>/`, authored via [usync-author](../usync-author/SKILL.md). Must have `<IsElement>true</IsElement>`. The `Key` GUID identifies it.
2. **Block editor DataType** under [Brand.Web/uSync/v17/DataTypes/](../../../Brand.Web/uSync/v17/DataTypes/) — authored in backoffice, captured by uSync. Its `Config` JSON lists which element types it accepts. Example: [BLHomePage.config](../../../Brand.Web/uSync/v17/DataTypes/BLHomePage.config) accepts `heroBanner` (Key `58cd990a-…`).
3. **Consumer page property** — a `<GenericProperty>` on the parent page's `.config` whose `<Definition>` points at the block DataType's `Key` and whose `<Type>` is `Umbraco.BlockList` / `Umbraco.BlockGrid`. Example: [Brand.Core/Pages/HomePage/homepage.config](../../../Brand.Core/Pages/HomePage/homepage.config) `components` property → `<Definition>830c5431-…</Definition>` (BLHomePage).
4. **Render path** — either a per-page dispatch in the page template, OR delegation through `Brand.Web/Views/Partials/`.

## Block editor DataType `Config` JSON

The block editor's `<Config><![CDATA[…]]></Config>` block contains the list of allowed element types and per-block options (label, settings element type, etc.). Example shape:

```json
{
  "blocks": [
    { "contentElementTypeKey": "58cd990a-e9cd-41f6-9f78-86d60e6e4790", "label": "Hero Banner - {{title}}" }
  ]
}
```

`contentElementTypeKey` = the `Key` from the IsElement doctype's `.config`. `label` uses Angular-style `{{property}}` templating against the element's properties.

**Don't hand-edit this JSON.** Author the DataType in backoffice (Settings → Data Types → BlockList or BlockGrid), use its UI to add/configure blocks, save. uSync exports the resulting `.config`. Spot-fixes (typo in a label, reordering blocks) are tolerable; structural changes go through backoffice.

## Render path A — direct ViewComponent dispatch on the page

Used today by [Brand.Web/Views/HomePage/HomePage.cshtml](../../../Brand.Web/Views/HomePage/HomePage.cshtml). The page template iterates blocks and invokes the ViewComponent matching each block's alias:

```cshtml
@foreach (var block in Model.Components)
{
    @await Component.InvokeAsync(block.Content.ContentType.Alias, new { source = block.Content })
}
```

Wiring:
- Every IsElement doctype must have a registered ViewComponent whose class name matches its alias (alias `heroBanner` → `HeroBannerViewComponent`). See [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md).
- The ViewComponent's `Invoke(Models.X source)` parameter takes the generated element class.

Choose this when the page knows its block set and there's no need for the generic partials.

## Render path B — partial-based dispatch via `Brand.Web/Views/Partials/`

For pages that defer rendering to Umbraco's standard block partials, the chain is:

- **Block List**: page template calls `@await Html.GetBlockListHtmlAsync(Model.MyBlocks)` (or similar). That hits [Brand.Web/Views/Partials/blocklist/default.cshtml](../../../Brand.Web/Views/Partials/blocklist/default.cshtml) which iterates and calls:
  ```cshtml
  @await Html.PartialAsync("blocklist/Components/" + data.ContentType.Alias, block)
  ```
  So each block needs a partial at `Views/Partials/blocklist/Components/<alias>.cshtml`.

- **Block Grid**: page template calls `@await Html.GetBlockGridHtmlAsync(...)`. That hits [Brand.Web/Views/Partials/blockgrid/default.cshtml](../../../Brand.Web/Views/Partials/blockgrid/default.cshtml) which delegates to `Html.GetBlockGridItemsHtmlAsync(Model)`. The framework resolves per-block partials under `Views/Partials/blockgrid/Components/<alias>.cshtml` (and area variants).

- **Single block**: [Brand.Web/Views/Partials/singleblock/default.cshtml](../../../Brand.Web/Views/Partials/singleblock/default.cshtml) renders one block via `Html.SingleBlockPartialWithFallback("singleBlock/Components/<alias>", "blocklist/Components/<alias>")` — falls back to the Block List component partial if no single-block-specific one exists.

Use this when the same block type renders identically across many pages and you want one canonical partial per block.

## Picking A or B for a new block

| Situation | Choose |
|---|---|
| Block is HomePage-specific, has bespoke layout | A (page-direct VC dispatch) — current HomePage pattern |
| Block is reused across many pages with identical render | B (partial under `Partials/blocklist/Components/`) |
| Block needs server-side logic before render (services, mapping) | A (ViewComponent gives DI + Invoke method) |
| Pure markup pass-through of a single property | B (partial — no VC needed) |

When unsure, **start with A** — moving from VC dispatch to partial dispatch later is mechanical.

## Adding a new block — full sequence

1. **Author the IsElement DocumentType** under `Brand.Core/Components/<Page>/<Name>/` using [usync-author](../usync-author/SKILL.md). Run `mise run usync:bundle`.
2. **Add the block to the block editor DataType** in backoffice — open the existing Block List/Grid DataType (e.g. `BL - Home Page`), add the new element type, save. uSync writes the change to `Brand.Web/uSync/v17/DataTypes/`.
3. **Pick the render path** (A or B):
   - **A**: author a `<Name>ViewComponent.cs` next to the `.config` and a `Brand.Web/Views/Shared/Components/<Name>/Default.cshtml` view, per [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md). The existing page template's `Component.InvokeAsync(block.Content.ContentType.Alias, ...)` picks it up automatically.
   - **B**: author `Brand.Web/Views/Partials/blocklist/Components/<alias>.cshtml`. No `.cs` needed.
4. **Boot the app** (`mise run dev`) — uSync imports the new doctype, ModelsBuilder regenerates the model, the new block shows up in the editor.

## Adding a new block editor DataType (whole new list/grid)

When the parent page needs a different element-type whitelist than any existing BL/BG DataType:

1. Backoffice → Settings → Data Types → Create → Block List (or Block Grid).
2. Configure the allowed element types.
3. Save. uSync exports `Brand.Web/uSync/v17/DataTypes/<Name>.config`.
4. On the consuming page's `.config`, add a `<GenericProperty>` whose `<Definition>` is the new DataType's `Key`. Run `mise run usync:bundle`.

Reuse beats create — if the existing editor accepts the right blocks and is named in a way that fits the new use, just consume it.

## Common mistakes

- **Forgetting `IsElement=true`** on the block's doctype. uSync imports it, but it won't show up in any block editor — the picker filters by `IsElement`.
- **`<Variations>Culture</Variations>` mismatch.** A page-level Block List property usually inherits its variation. Element types are typically `Variations=Nothing`. Mixing them silently drops translations or duplicates values per culture. Keep elements `Nothing` unless you specifically need per-culture block content.
- **Adding a new element to a DataType in backoffice but forgetting to commit `Brand.Web/uSync/v17/DataTypes/<Name>.config`.** The block works locally but no other env sees it.
- **VC name ≠ alias.** Direct dispatch (`Component.InvokeAsync(alias, ...)`) matches by lowercased class-name-minus-suffix. Alias `heroBanner` finds `HeroBannerViewComponent`. If you rename one without the other, dispatch silently no-ops for that block.

## When to invoke this skill

- User asks to add a new block to a page.
- User asks "Block List or Block Grid?" or how to decide between block editor types.
- User is wiring an IsElement doctype into a block editor.
- User is debugging why a block doesn't render or doesn't appear in the editor's picker.
- User is editing partials under `Brand.Web/Views/Partials/{blockgrid,blocklist,singleblock}/`.

## When NOT to invoke this skill

- Authoring the IsElement DocumentType `.config` itself → [usync-author](../usync-author/SKILL.md).
- Writing the ViewComponent or ViewModel → [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md).
- Picking a non-block DataType for a regular property → [umbraco-datatypes](../umbraco-datatypes/SKILL.md).
- Hand-editing block editor `Config` JSON — use backoffice.
