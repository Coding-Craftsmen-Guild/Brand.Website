using Brand.Core.Components.UI.Section;
using Microsoft.AspNetCore.Razor.TagHelpers;
using TailwindMerge;

namespace Brand.Web.TagHelpers;

// Code-only section wrapper. Renders the standard outer chrome plus the inner
// `.wrapper` so Razor children land in the centred, gutter-padded column. Authored as a
// tag helper rather than a ViewComponent because only tag helpers accept children.
//
//   <section-block class="bg-marble">
//       <h2>@Model.Title</h2>
//   </section-block>
//
// Full-bleed bands opt out of both the container and the padding — the hero and the
// standard banner are edge-to-edge and pad against the fixed header themselves:
//
//   <section-block variant="full-bleed" data-component="hero-banner"> … </section-block>
[HtmlTargetElement("section-block")]
public sealed class SectionTagHelper(TwMerge twMerge) : TagHelper
{
    // "contained" (default) | "full-bleed"
    [HtmlAttributeName("variant")]
    public string Variant { get; set; }

    public override async Task ProcessAsync(TagHelperContext context, TagHelperOutput output)
    {
        output.TagName = "section";
        output.TagMode = TagMode.StartTagAndEndTag;

        // Every other attribute written on <section-block> (id, aria-*, data-*) passes
        // through to <section> automatically; only default data-component when the
        // caller didn't name the component itself.
        if (!output.Attributes.ContainsName("data-component"))
        {
            output.Attributes.SetAttribute("data-component", "section");
        }

        var fullBleed = SectionVariants.IsFullBleed(Variant);
        var chrome = fullBleed ? SectionVariants.FullBleed : SectionVariants.Contained;

        // `class` written on the element is folded in through TwMerge so a per-instance
        // override actually wins instead of colliding.
        var extra = output.Attributes["class"]?.Value?.ToString() ?? string.Empty;
        output.Attributes.SetAttribute("class", twMerge.Merge(chrome, extra) ?? string.Empty);

        var children = await output.GetChildContentAsync();

        if (fullBleed)
        {
            output.Content.SetHtmlContent(children);
            return;
        }

        output.Content.AppendHtml($"<div class=\"{SectionVariants.Inner}\">");
        output.Content.AppendHtml(children);
        output.Content.AppendHtml("</div>");
    }
}
