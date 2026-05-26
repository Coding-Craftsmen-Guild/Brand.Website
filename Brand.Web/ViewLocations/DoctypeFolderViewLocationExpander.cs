using Microsoft.AspNetCore.Mvc.Razor;

namespace Brand.Web.ViewLocations;

// Lets an Umbraco template live in its own folder: /Views/<TemplateAlias>/<TemplateAlias>.cshtml
// is checked before the default /Views/<TemplateAlias>.cshtml.
public sealed class DoctypeFolderViewLocationExpander : IViewLocationExpander
{
    public void PopulateValues(ViewLocationExpanderContext context) { }

    public IEnumerable<string> ExpandViewLocations(
        ViewLocationExpanderContext context,
        IEnumerable<string> viewLocations
    )
    {
        return new[] { "/Views/{0}/{0}.cshtml" }.Concat(viewLocations);
    }
}
