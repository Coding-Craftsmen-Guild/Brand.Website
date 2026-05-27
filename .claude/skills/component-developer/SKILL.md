---
name: component-developer
description: Entry-point orchestrator for adding any new component to this site. Picks the bucket (pure UI, page-scoped block, shared block, site-wide composition) from a short decision tree, then delegates the mechanical work to usync-author, umbraco-datatypes, umbraco-viewcomponent and umbraco-blocks. Use when the user asks to "create a component", "build me a [accordion / card / banner / hero / quote / ...]", "add a [thing] on the [page]", "make a reusable [thing]", "add a [thing] to the header/footer", or anything that introduces new UI to the site.
---

# component-developer

The single entry point for "build me a component" requests in this repo. This skill owns the **decision** — which bucket the component belongs to and which specialised skills to chain — but delegates all mechanical authoring to:

- [usync-author](../usync-author/SKILL.md) — `.config` authoring, GUID uniqueness, bundler.
- [umbraco-datatypes](../umbraco-datatypes/SKILL.md) — picking/creating the property editor for each field.
- [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md) — `ViewComponent` + `ViewModel` record + Razor partial.
- [umbraco-blocks](../umbraco-blocks/SKILL.md) — block list/grid wiring when the component is an `IsElement` block.

Always read `### Component taxonomy` in [CLAUDE.md](../../../CLAUDE.md) before starting — it's the source of truth for folder layout.

## Decision tree — answer in order

Before any file is created, walk these three questions. The bucket falls out of the answers.

1. **Does the component need editor-managed content (fields the editor fills in via the Umbraco backoffice)?**
   - **No** → pure UI. Bucket: `Brand.Core/Components/UI/<Name>/`. Jump to [Pure UI flow](#pure-ui-flow).
   - **Yes** → continue.
2. **Is it a site-wide singleton — i.e. Header, Footer, GlobalSettings or another piece of chrome that exists exactly once per site?**
   - **Yes** → bucket: `Brand.Core/Compositions/<Name>/` (mixin, `IsElement=false`). Jump to [Composition flow](#composition-flow).
   - **No** → continue.
3. **Will this block be used on exactly one page type, or across multiple page types?**
   - **One page** → bucket: `Brand.Core/Components/<Page>/<Name>/` (page-scoped, `IsElement=true`).
   - **Multiple pages** → bucket: `Brand.Core/Shared/<Name>/` (cross-page reusable, `IsElement=true`).

When unsure between page-scoped and shared, **start page-scoped**. Promotion to `Shared/` later is mechanical: move the folder, rename the namespace, register the doctype in the additional page block-list DataType(s). Demotion the other way is breaking because consumers already depend on it.

## Bucket → folder → skill mapping

| Bucket | Folder | `.config`? | DataTypes? | Block-listable? | Skills to invoke (in order) |
|---|---|---|---|---|---|
| Pure UI | `Brand.Core/Components/UI/<Name>/` | No | No | No | umbraco-viewcomponent (ViewComponent + Variants + partial only) |
| Page-scoped block | `Brand.Core/Components/<Page>/<Name>/` | Yes (IsElement=true) | Yes | Yes | umbraco-datatypes → usync-author → umbraco-blocks → umbraco-viewcomponent |
| Shared block | `Brand.Core/Shared/<Name>/` | Yes (IsElement=true) | Yes | Yes (across pages) | umbraco-datatypes → usync-author → umbraco-blocks → umbraco-viewcomponent |
| Site-wide composition | `Brand.Core/Compositions/<Name>/` | Yes (IsElement=false mixin) | Yes | No | umbraco-datatypes → usync-author → umbraco-viewcomponent (interface-based `Invoke`) |

## Pure UI flow

Pure UI components are plain Razor ViewComponents with no Umbraco backing — they're invoked inline by other components.

1. Create `Brand.Core/Components/UI/<Name>/<Name>ViewComponent.cs` with `namespace Brand.Core.Components.UI.<Name>;`. Define a `sealed record <Name>ViewModel(...)` and a `sealed class <Name>ViewComponent : ViewComponent` whose `Invoke(...)` takes primitive parameters (caller passes them).
2. Create `Brand.Core/Components/UI/<Name>/<Name>Variants.cs` next to it — `public static class <Name>Variants` with a `Base` constant and `Variant(string)` / `Size(string)` methods. Tailwind picks the class strings up automatically via the `@source "../../Brand.Core/**/*.cs"` scan in [Brand.Web/Client/main.css](../../../Brand.Web/Client/main.css).
3. Create the partial at `Brand.Web/Views/Shared/Components/<Name>/Default.cshtml` with `@model Brand.Core.Components.UI.<Name>.<Name>ViewModel` and `@using Brand.Core.Components.UI.<Name>`. Compose classes via `@Html.Cn(<Name>Variants.Base, ...)`.
4. (Optional) Co-locate `<name>.ts` / `<name>.scss` next to the partial under `Brand.Web/Views/Shared/Components/<Name>/` for interactive behaviour and component-scoped styles. Vite picks them up via the glob in `main.ts`.

No `.config`, no bundling, no DataTypes, no block editor wiring. Reference: [Button](../../../Brand.Core/Components/UI/Button/) is the canonical pure-UI example.

Defer the mechanical Razor/ViewComponent pieces to [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md) — but skip its `Models.X` shadow-workaround section (there's no generated model for a pure-UI component).

## Composition flow

Site-wide singletons (Header, Footer, GlobalSettings) — one instance per site, content lives at the root.

1. **Pick datatypes** for each property — delegate to [umbraco-datatypes](../umbraco-datatypes/SKILL.md).
2. **Author the `.config`** at `Brand.Core/Compositions/<Name>/<name>.config` with `IsElement=false`. Delegate to [usync-author](../usync-author/SKILL.md) (it enforces GUID uniqueness and the local-tab gotcha).
3. **Author the ViewComponent** at `Brand.Core/Compositions/<Name>/<Name>ViewComponent.cs` — `Invoke(I<Name> source)` takes the **interface** (see [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md) for the namespace-shadow rule with `Models.`). Use `UmbracoHelper.ContentAtRoot().OfType<I<Name>>().FirstOrDefault()` to fetch the singleton, map to the ViewModel.
4. **Partial** at `Brand.Web/Views/Shared/Components/<Name>/Default.cshtml`.
5. **Invocation** is by name from `_Layout.cshtml` (or wherever the chrome lives): `@await Component.InvokeAsync("<Name>")` — no args.
6. Run `mise run usync:bundle` after authoring the `.config`.

Reference: [Header](../../../Brand.Core/Compositions/Header/) is the canonical example.

## Block flow (page-scoped or shared)

Doctype that's listed in a block editor and rendered by the page template.

1. **Pick datatypes** for each property — delegate to [umbraco-datatypes](../umbraco-datatypes/SKILL.md). If a needed editor isn't already in the index, decide whether to reuse a close fit (e.g. Textstring for an icon class name) or create one via the backoffice.
2. **Author the `.config`** at:
   - `Brand.Core/Components/<Page>/<Name>/<name>.config` for page-scoped, **or**
   - `Brand.Core/Shared/<Name>/<name>.config` for cross-page reusable.

   Both use `IsElement=true`. Delegate to [usync-author](../usync-author/SKILL.md) for GUIDs, the local `content` tab, and property wiring.
3. **Register in the block editor DataType** — in the Umbraco backoffice, open the relevant block-list DataType (e.g. `BL - Home Page` for `Components/HomePage/`, or each consuming page's BL for a `Shared/` block) and add the new alias to its allowed element types. uSync exports the change to `Brand.Web/uSync/v17/DataTypes/`. Delegate the wiring choice (BlockList vs BlockGrid vs single block) to [umbraco-blocks](../umbraco-blocks/SKILL.md).
4. **Author the ViewComponent** at `<bucket>/<Name>/<Name>ViewComponent.cs` — `Invoke(Models.<Name> source)` takes the **class** (use the `Models.` prefix per the namespace-shadow workaround). Map to a `<Name>ViewModel` record.
5. **Partial** at `Brand.Web/Views/Shared/Components/<Name>/Default.cshtml`.
6. **Dispatch** is automatic — the page template's `Component.InvokeAsync(block.Content.ContentType.Alias, ...)` picks up the new component by alias.
7. Run `mise run usync:bundle` after authoring the `.config`. Restart the dev server so uSync re-imports.

Reference: [HeroBanner](../../../Brand.Core/Components/HomePage/HeroBanner/) is the canonical page-scoped block.

## Worked example A — "Create me a component on the homepage that is an accordion with fields: title, icon, text"

1. **Decision tree**: editor-managed → yes; site-wide singleton → no; one page (homepage) → **bucket = `Brand.Core/Components/HomePage/Accordion/`**.
2. **Datatypes** — delegate to [umbraco-datatypes](../umbraco-datatypes/SKILL.md):
   - `title` → reuse `Textstring.config` (`Umbraco.TextBox`).
   - `icon` → check the index for an icon picker; if none, reuse `Textstring` for an icon class name (cheapest) or create one in the backoffice.
   - `text` → reuse `Textarea.config` (or `RichtextEditor.config` if the editor needs formatting — ask the user).
3. **`.config`** — delegate to [usync-author](../usync-author/SKILL.md). Generate a v4 GUID for the doctype Key, one per `<GenericProperty>`, one for the `<Tab>`. Verify uniqueness across every `.config` in the repo. Set `IsElement=true`, `Folder=Components/HomePage`, declare a local `content` tab, bind each property to the DataType GUID picked in step 2.
4. **Block editor wiring** — delegate to [umbraco-blocks](../umbraco-blocks/SKILL.md). Add `accordion` to the `BL - Home Page` block list DataType in the backoffice. uSync writes the change to `Brand.Web/uSync/v17/DataTypes/BLHomePage.config`.
5. **ViewComponent + partial** — delegate to [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md):
   - `Brand.Core/Components/HomePage/Accordion/AccordionViewComponent.cs` with `namespace Brand.Core.Components.HomePage.Accordion;`, `Invoke(Models.Accordion source)`, map to `AccordionViewModel(string Title, string Icon, string Text)`.
   - `Brand.Web/Views/Shared/Components/Accordion/Default.cshtml` with `@model Brand.Core.Components.HomePage.Accordion.AccordionViewModel`.
   - Optional co-located `accordion.ts` + `accordion.scss` for open/close behaviour using `defineComponent('[data-component="accordion"]', ...)`.
6. `mise run usync:bundle`, restart, add an Accordion block in the homepage backoffice, save, view the homepage.

## Worked example B — "Add a Card UI component with title, image, body and a CTA button — no Umbraco"

1. **Decision tree**: no editor-managed content → **bucket = `Brand.Core/Components/UI/Card/`**. Skip usync-author, umbraco-datatypes, umbraco-blocks.
2. `Brand.Core/Components/UI/Card/CardViewComponent.cs` — `namespace Brand.Core.Components.UI.Card;`, `Invoke(string title, string body, string imageUrl = "", string ctaLabel = "", string ctaHref = "")`, return `View(new CardViewModel(...))`.
3. `Brand.Core/Components/UI/Card/CardVariants.cs` — `public static class CardVariants` with `Base`, `Variant(string)`, `Size(string)`. Mirror `ButtonVariants`.
4. `Brand.Web/Views/Shared/Components/Card/Default.cshtml` — `@model Brand.Core.Components.UI.Card.CardViewModel`, compose classes with `@Html.Cn(CardVariants.Base, ...)`. When a CTA is set, embed Button: `@await Component.InvokeAsync("Button", new { label = Model.CtaLabel, href = Model.CtaHref })`.
5. Use it anywhere: `@await Component.InvokeAsync("Card", new { title = "...", body = "..." })`.

No `.config`, no bundle, no DataTypes, no block wiring. This is the canonical pure-UI path.

## Conventions reminders

- **Namespace = folder path under `Brand.Core/`.** `Components/UI/Card/` → `Brand.Core.Components.UI.Card`. `Components/HomePage/Accordion/` → `Brand.Core.Components.HomePage.Accordion`. `Shared/Quote/` → `Brand.Core.Shared.Quote`. `Compositions/Header/` → `Brand.Core.Compositions.Header`.
- **ViewModel record lives next to the ViewComponent** in the same `.cs` file — see [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md).
- **Razor partial** always at `Brand.Web/Views/Shared/Components/<Name>/Default.cshtml`. Discovery is by ViewComponent class-name-minus-`ViewComponent`, not by source folder.
- **Co-located `.ts` / `.scss`** live next to the partial under `Brand.Web/Views/Shared/Components/<Name>/`, not next to the `.cs`. Vite picks them up via `import.meta.glob('../Views/**/*.{ts,scss}', { eager: true })` in [main.ts](../../../Brand.Web/Client/main.ts).
- **Variants** (`<Name>Variants.cs`) live next to the ViewComponent in `Brand.Core/`. Tailwind scans `../../Brand.Core/**/*.cs` so any bucket works.
- **`Invoke` signature**: Compositions take an **interface** (`IHeader`), `Components/<Page>/` and `Shared/` blocks take the **class** (`Models.X`), pure UI takes **primitives**.
- **Pure UI never needs the `Models.X` shadow workaround** — there's no generated model.

## See also

- [usync-author](../usync-author/SKILL.md) — `.config` authoring, GUIDs, bundler.
- [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md) — ViewComponent + ViewModel + partial mechanics.
- [umbraco-datatypes](../umbraco-datatypes/SKILL.md) — picking property editors.
- [umbraco-blocks](../umbraco-blocks/SKILL.md) — block editor composition + render dispatch.
- [CLAUDE.md](../../../CLAUDE.md) — `### Component taxonomy` section.

## When NOT to invoke this skill

- The user is editing an *existing* component — go straight to the relevant specialised skill (usync-author for `.config` edits, umbraco-viewcomponent for `.cs`/`.cshtml`, etc.).
- The user is fixing styling/classes only — no taxonomy decision involved.
- The user is asking about non-component concerns (uSync bundler, Docker, Vite config, mise tasks, etc.).
