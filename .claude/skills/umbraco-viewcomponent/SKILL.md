---
name: umbraco-viewcomponent
description: Author Razor render code for Umbraco DocumentTypes AND pure-UI ViewComponents — co-located ViewComponent + ViewModel record under Brand.Core/{Components,Compositions,Shared}/, the Models.X namespace-shadow workaround, the Compositions-take-interface rule, pure-UI takes-primitives variant, and where to put the Default.cshtml partial. Use when adding a render path for a doctype, mapping a generated PublishedContentModel to a strongly-typed view, wiring block-list items into ViewComponent dispatch, or authoring a pure-UI component like Button/Card.
---

# umbraco-viewcomponent

Razor render layer for code-first Umbraco DocumentTypes **and** pure-UI ViewComponents. The doctype `.config` and Brand.Core source layout is owned by the [usync-author](../usync-author/SKILL.md) skill; the bucket-selection decision tree is owned by the [component-developer](../component-developer/SKILL.md) skill — this skill covers the C# + Razor side only.

## Co-location pattern

A ViewComponent and its ViewModel live in the same `.cs` file, in the same folder. For Umbraco-backed doctypes that's the same folder as the source `.config` (see the layout in [usync-author](../usync-author/SKILL.md#source-layout)). For **pure UI components** under `Brand.Core/Components/UI/<Name>/`, there's no `.config` — the folder holds just the `<Name>ViewComponent.cs` plus an optional `<Name>Variants.cs`.

File convention:

- Filename: `<Name>ViewComponent.cs` (PascalCase).
- Namespace: `Brand.Core.<Category>.<...>.<Name>` matching the folder path.
- Both **`<Name>ViewModel`** (a sealed `record` of primitives + Umbraco render-ready types like `MediaWithCrops`, `Link`, `IPublishedContent`) and **`<Name>ViewComponent`** (a `sealed class : ViewComponent`) live in the same `.cs`.

Canonical example: [Brand.Core/Components/HomePage/HeroBanner/HeroBannerViewComponent.cs](../../../Brand.Core/Components/HomePage/HeroBanner/HeroBannerViewComponent.cs).

```csharp
public sealed record HeroBannerViewModel(
    string Title,
    string Text,
    MediaWithCrops Background,
    IEnumerable<Link> Buttons
);

public sealed class HeroBannerViewComponent : ViewComponent
{
    public IViewComponentResult Invoke(Models.HeroBanner source)
    {
        var vm = new HeroBannerViewModel(
            Title: source.Title,
            Text: source.Text,
            Background: source.Background,
            Buttons: source.Buttons
        );
        return View(vm);
    }
}
```

Rules:

- Map model → ViewModel **inside `Invoke`**. Never pass the raw generated model to the Razor view.
- ViewModel is a `record` (positional, immutable). The view binds against it.
- The ViewComponent only orchestrates: pull values off `source`, project into the VM, return `View(vm)`.

## Invoke signature: interface (Compositions) vs model (Components/Shared) vs primitives (Pure UI)

- **Compositions** (`Brand.Core/Compositions/<Name>/`) — `Invoke` takes the generated **interface** (`IHeader`, `IFooter`). This lets any page that composes the mixin pass itself in. See [HeaderViewComponent.cs](../../../Brand.Core/Compositions/Header/HeaderViewComponent.cs).
- **Page-scoped Components** (`Brand.Core/Components/<Page>/<Name>/`, `IsElement=true`) — `Invoke` takes the generated **class** (`Models.HeroBanner`). Elements aren't shared; the concrete type is fine.
- **Shared blocks** (`Brand.Core/Shared/<Name>/`, `IsElement=true`) — same as page-scoped Components: `Invoke` takes the generated class via `Models.<Name>`.
- **Pure UI** (`Brand.Core/Components/UI/<Name>/`) — `Invoke` takes **plain primitives** passed by the caller (e.g. `Invoke(string label, string href = "", string variant = "primary", string size = "md")`). No `source` parameter, no `Models.X` reference, no generated model exists. See [ButtonViewComponent.cs](../../../Brand.Core/Components/UI/Button/ButtonViewComponent.cs) for the canonical example.
- **Pages** (`Brand.Core/Pages/<Name>/`) typically render via their template (`Views/<Alias>/<Alias>.cshtml`), not a ViewComponent. Skip the VC unless a page needs to be embedded somewhere as a fragment.

## Namespace-vs-class collision

Folders like `Brand.Core/Components/HomePage/HeroBanner/` make the C# namespace `Brand.Core.Components.HomePage.HeroBanner`. The ModelsBuilder-generated class is `Brand.Core.Models.HeroBanner`. Inside the folder's namespace, the unqualified name `HeroBanner` resolves to the **namespace**, not the class — the namespace shadows it.

Workaround: reference the model with the `Models.` prefix:

```csharp
public IViewComponentResult Invoke(Models.HeroBanner source) { ... }
```

`Models.` is the alias picked up from `using Brand.Core.Models;` at the top of the file. Don't fully qualify (`Brand.Core.Models.HeroBanner`) — `Models.X` is the established convention.

## Where the Razor partial lives

ASP.NET Core ViewComponent discovery looks under `Views/Shared/Components/<ComponentName>/Default.cshtml`. The view is **NOT** co-located with the `.cs` source — it lives under `Brand.Web/`:

```
Brand.Web/Views/Shared/Components/
├── Header/Default.cshtml
├── Footer/Default.cshtml
└── HeroBanner/Default.cshtml
```

The `<ComponentName>` folder matches the class name minus the `ViewComponent` suffix (`HeroBannerViewComponent` → `HeroBanner/`). The view inherits the ViewModel:

```cshtml
@model Brand.Core.Components.HomePage.HeroBanner.HeroBannerViewModel
```

`Brand.Web/Views/_ViewImports.cshtml` already imports the relevant namespaces — confirm before adding fully-qualified `@model` references.

## Custom template discovery (pages)

A page template can live at either `Views/<Alias>.cshtml` (default) or `Views/<Alias>/<Alias>.cshtml` (preferred — keeps related view files together). The second location is enabled by [Brand.Web/ViewLocations/DoctypeFolderViewLocationExpander.cs](../../../Brand.Web/ViewLocations/DoctypeFolderViewLocationExpander.cs), registered in `Program.cs`. Example: [Brand.Web/Views/HomePage/HomePage.cshtml](../../../Brand.Web/Views/HomePage/HomePage.cshtml).

## Block dispatch pattern

When a page renders a Block List property, the page template iterates blocks and invokes the matching ViewComponent by `ContentType.Alias`:

```cshtml
@foreach (var block in Model.Components)
{
    @await Component.InvokeAsync(block.Content.ContentType.Alias, new { source = block.Content })
}
```

See [Brand.Web/Views/HomePage/HomePage.cshtml](../../../Brand.Web/Views/HomePage/HomePage.cshtml) for the live example. Each block's element type has a registered ViewComponent whose name matches its alias (e.g. alias `heroBanner` → `HeroBannerViewComponent`).

For richer dispatch (Block List/Grid/single) via partials in `Brand.Web/Views/Partials/`, see the [umbraco-blocks](../umbraco-blocks/SKILL.md) skill.

## When to skip the ViewComponent

Not every doctype needs one:

- **Pages** rendered via their template (`Views/<Alias>/<Alias>.cshtml`) — no VC needed unless the page is also embedded as a fragment elsewhere.
- **Settings-only compositions** (e.g. `GlobalSettings`) that hold properties but have no render output of their own — the consumer reads `source.SomeProperty` directly in its template/VM.
- **DataTypes, MediaTypes, MemberTypes, Templates** — these are not DocumentTypes; no render layer applies.

## When to invoke this skill

- User asks to add or modify the render layer for a doctype.
- User is editing or creating a `*ViewComponent.cs` file under `Brand.Core/`.
- User is editing a `Default.cshtml` under `Brand.Web/Views/Shared/Components/`.
- User asks why a generated class is shadowed by a namespace (`Models.X` workaround question).
- User is wiring up block dispatch on a page template.

## When NOT to invoke this skill

- Authoring the doctype `.config` itself → [usync-author](../usync-author/SKILL.md).
- Choosing which DataType a property should use → [umbraco-datatypes](../umbraco-datatypes/SKILL.md).
- Designing a Block List/Grid composition (which blocks belong where) → [umbraco-blocks](../umbraco-blocks/SKILL.md).
- Editing ModelsBuilder-generated files under `Brand.Core/Generated/` — off-limits per [CLAUDE.md](../../../CLAUDE.md) `## Umbraco specifics`.
