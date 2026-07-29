namespace Brand.Core.Components.UI.Section;

// Section chrome for the design's vertical rhythm. Spacing lives *inside* a section as
// padding, never as section-to-section margin, so blocks reorder without doubling or
// collapsing gaps.
public static class SectionVariants
{
    // Full-bleed bands (hero, standard banner) break the container and carry no section
    // padding — each supplies its own, because they pad against the fixed header.
    public const string FullBleed = "relative isolate";

    // Contained sections own symmetric top/bottom padding: --section-pad-y is 96px,
    // dropping to 48px under the design's 700px breakpoint.
    public const string Contained = "relative isolate py-24 max-[700px]:py-12";

    public const string Inner = "wrapper";

    public static bool IsFullBleed(string variant) =>
        string.Equals(variant, "full-bleed", StringComparison.OrdinalIgnoreCase);
}
