---
name: umbraco-datatypes
description: Pick or create Umbraco DataTypes for a code-first doctype property — indexes the existing DataTypes under Brand.Web/uSync/v17/DataTypes/ with their EditorAlias and Key, the rule that DataTypes are backoffice-authored (uSync auto-exports them on save, not code-first), and when to reuse vs create-via-backoffice. Use when adding a property to a .config and choosing the <Definition> GUID, or when the editor you need isn't already in the index.
---

# umbraco-datatypes

DataTypes are the property editor instances that doctype properties point at. A property in a `.config` references a DataType by GUID in its `<Definition>` element:

```xml
<GenericProperty>
  <Alias>title</Alias>
  <Definition>0cc0eba1-9960-42c9-bf9b-60e150b429ae</Definition>  <!-- Textstring DataType -->
  <Type>Umbraco.TextBox</Type>
  ...
</GenericProperty>
```

`<Definition>` is the DataType `Key`. `<Type>` is the property editor alias (must match the DataType's `EditorAlias`). Get them both right or Umbraco logs a load error and the property goes empty.

## DataTypes are backoffice-authored, NOT code-first

This is the inverse of DocumentTypes. Per [appsettings.json](../../../Brand.Web/appsettings.json) and [appsettings.Development.json](../../../Brand.Web/appsettings.Development.json):

- **Prod**: `ExportOnSave: "All"` — every backoffice DataType save writes `.config` to disk.
- **Dev**: `ExportOnSave: "Settings"` — same effect for DataTypes (Settings handlers include `DataTypeHandler`).
- `DataTypes/` is **tracked in git** (unlike `ContentTypes/`). It IS the source of truth.

**Authoring workflow:**
1. Open the backoffice → Settings → Data Types → create/edit.
2. uSync auto-exports to [Brand.Web/uSync/v17/DataTypes/](../../../Brand.Web/uSync/v17/DataTypes/).
3. Commit the new/changed `.config` alongside whatever doctype change consumes it.

Do **not** hand-author DataType `.config` XML. Always go through the backoffice. uSync's GUID generation, editor schema, and config JSON shape are easy to get subtly wrong, and the round-trip via backoffice gives a working file every time.

## Index — DataTypes currently tracked

Authoritative list lives in [Brand.Web/uSync/v17/DataTypes/](../../../Brand.Web/uSync/v17/DataTypes/). Below is a grouped quick-reference. Grep the actual `.config` for `Key=` and `EditorAlias` when wiring a property.

### Text

| File | EditorAlias | Use for |
|---|---|---|
| Textstring.config | `Umbraco.TextBox` | titles, single-line headings, short labels |
| Textarea.config | `Umbraco.TextArea` | summaries, descriptions, plain-text blurbs |
| RichtextEditor.config | `Umbraco.RichText` / `Umbraco.TinyMCE` | rich body copy with toolbar |
| Tags.config | `Umbraco.Tags` | free-text tag arrays |

### Numeric / boolean

| File | EditorAlias | Use for |
|---|---|---|
| Numeric.config | `Umbraco.Integer` / `Umbraco.Decimal` | numeric input |
| Truefalse.config | `Umbraco.TrueFalse` | boolean toggle |

### Date / time

| File | EditorAlias | Use for |
|---|---|---|
| DatePicker.config | `Umbraco.DateTime` | date-only |
| DatePickerWithTime.config | `Umbraco.DateTime` | date + time |
| DateTimePickerWithTimeZone.config | `Umbraco.DateTime` | date + time + tz |

### Selectors (text-based)

| File | EditorAlias | Use for |
|---|---|---|
| Dropdown.config | `Umbraco.DropDown.Flexible` | single-select from fixed list |
| DropdownMultiple.config | `Umbraco.DropDown.Flexible` | multi-select from fixed list |
| CheckboxList.config | `Umbraco.CheckBoxList` | multi-check from fixed list |
| Radiobox.config | `Umbraco.RadioButtonList` | single-pick from fixed list |
| ApprovedColor.config | `Umbraco.ColorPicker` | colour from approved palette |

### Content / member / URL pickers

| File | EditorAlias | Use for |
|---|---|---|
| ContentPicker.config | `Umbraco.ContentPicker` | pick a Content node |
| MemberPicker.config | `Umbraco.MemberPicker` | pick a Member |
| MultiURLPicker.config | `Umbraco.MultiUrlPicker` | array of internal/external links (returns `IEnumerable<Link>`) |

### Media

| File | EditorAlias | Use for |
|---|---|---|
| MediaPicker.config | `Umbraco.MediaPicker3` | any media, single — yields `MediaWithCrops` |
| MultipleMediaPicker.config | `Umbraco.MediaPicker3` | any media, multiple |
| ImageMediaPicker.config | `Umbraco.MediaPicker3` | constrained to images, single |
| MultipleImageMediaPicker.config | `Umbraco.MediaPicker3` | constrained to images, multiple |
| ImageCropper.config | `Umbraco.ImageCropper` | upload + define crop variants on a single image |
| UploadFile.config / UploadAudio.config / UploadVideo.config / UploadArticle.config / UploadVectorGraphics.config | upload variants | direct file upload, type-constrained |

### Blocks

| File | EditorAlias | Use for |
|---|---|---|
| BLHomePage.config | `Umbraco.BlockList` | HomePage `components` property — wires the `heroBanner` IsElement |

For the IsElement wiring inside a block editor's `Config` JSON, see [umbraco-blocks](../umbraco-blocks/SKILL.md).

### Labels (readonly display)

`Label*.config` files all use `Umbraco.Label` with a `valueType` flag (string / int / bigint / decimal / datetime / time / bytes / pixels). Use these for derived/calculated values shown in the backoffice but not editable.

### List views (admin)

`ListViewContent.config`, `ListViewMedia.config` — admin list-view configurations. Not used as property `<Definition>`; referenced via `<ListView>` on a ContentType.

## Picking a DataType for a new property

Decision flow:

1. **Look at the index above and grep [DataTypes/](../../../Brand.Web/uSync/v17/DataTypes/)** for an existing match. If `EditorAlias` matches and the existing config (`<Config><![CDATA[…]]></Config>` JSON) is acceptable, reuse it — copy its `Key` into the property's `<Definition>` and its alias-as-`Umbraco.X` into `<Type>`.
2. **Reuse beats create** unless the configuration genuinely differs:
   - Different dropdown value set → new DataType.
   - Different image cropper crops → new DataType.
   - Block List with a different element-type whitelist → new DataType (see [umbraco-blocks](../umbraco-blocks/SKILL.md)).
   - Same editor + same config + different doctype consumer → **reuse**.
3. **If you need a new one**: backoffice → Settings → Data Types → Create. Don't hand-write the `.config`. After saving, uSync exports it; commit alongside the doctype change.

## Common mistakes

- **`<Type>` ≠ `EditorAlias`.** `<Type>` on a property is the editor alias from the DataType. If you copy a property block from another doctype and change the `<Definition>` GUID to a different editor, you must also change `<Type>` to match. Mismatch = property loads as raw.
- **Stale `<Definition>` after a backoffice rebuild.** If you delete and recreate a DataType in backoffice, the new one has a fresh `Key`. Properties pointing at the old GUID stop binding. Grep `<Definition>STALE-GUID</Definition>` across `Brand.Core/` before deleting any DataType.
- **Hand-editing a DataType `.config`.** Don't. The Block List `Config` JSON in particular has schema that's painful to hand-write; let backoffice generate it. Spot-fixes (e.g. a typo in a `Folder` value) are fine but anything structural belongs in backoffice.

## When to invoke this skill

- User is adding a property to a `.config` under `Brand.Core/` and asking which DataType to use.
- User asks "what editor do I use for X?" (rich text, media, multi-select, etc.).
- User wants to know if a needed editor already exists or has to be created.
- User is debugging a property that loads empty or as raw text — likely a `<Definition>`/`<Type>` mismatch.

## When NOT to invoke this skill

- Hand-editing DataType `.config` XML — use backoffice instead.
- Authoring the doctype itself → [usync-author](../usync-author/SKILL.md).
- Wiring a Block List to specific element types (block editor `Config` JSON) → [umbraco-blocks](../umbraco-blocks/SKILL.md).
- Writing render code → [umbraco-viewcomponent](../umbraco-viewcomponent/SKILL.md).
