using Microsoft.AspNetCore.Html;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.Extensions.DependencyInjection;
using TailwindMerge;

namespace Brand.Web.Extensions;

public static class HtmlClassExtensions
{
    public static IHtmlContent Cn(this IHtmlHelper html, params string[] classNames)
    {
        var twMerge = html.ViewContext.HttpContext.RequestServices.GetRequiredService<TwMerge>();
        var merged = twMerge.Merge(classNames) ?? string.Empty;
        return new HtmlString(merged);
    }
}
