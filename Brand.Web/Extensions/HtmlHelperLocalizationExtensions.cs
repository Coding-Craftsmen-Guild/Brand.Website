using Brand.Core.Localization;
using Microsoft.AspNetCore.Html;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.Extensions.DependencyInjection;

namespace Brand.Web.Extensions;

public static class HtmlHelperLocalizationExtensions
{
    // @Html.T("Some.Key") — resolves a dictionary value for the current culture.
    // Values are trusted plain-text dictionary entries, so they're emitted via
    // HtmlString to avoid double-encoding. A miss renders the key (see ILocalizer).
    public static IHtmlContent T(this IHtmlHelper html, string key)
    {
        var localizer =
            html.ViewContext.HttpContext.RequestServices.GetRequiredService<ILocalizer>();
        return new HtmlString(localizer[key]);
    }

    public static IHtmlContent T(this IHtmlHelper html, string key, params object[] args)
    {
        var localizer =
            html.ViewContext.HttpContext.RequestServices.GetRequiredService<ILocalizer>();
        return new HtmlString(localizer.T(key, args));
    }

    // String-returning variant for attribute/expression contexts where IHtmlContent
    // won't compose (e.g. inside an aria-label="@(cond ? Html.Tr("x") : y)"). Named
    // Tr (not Localize) to avoid colliding with Umbraco's IHtmlHelper extensions.
    public static string Tr(this IHtmlHelper html, string key)
    {
        var localizer =
            html.ViewContext.HttpContext.RequestServices.GetRequiredService<ILocalizer>();
        return localizer[key];
    }
}
