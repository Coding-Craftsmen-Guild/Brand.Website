using Microsoft.AspNetCore.Mvc;

namespace Brand.Core.Compositions.Button;

public sealed record ButtonViewModel(
    string Label,
    string Href,
    string Target,
    string Variant,
    string Size
);

public sealed class ButtonViewComponent : ViewComponent
{
    public IViewComponentResult Invoke(
        string label,
        string href = "",
        string target = "",
        string variant = "primary",
        string size = "md")
    {
        var vm = new ButtonViewModel(
            Label: label,
            Href: href,
            Target: target,
            Variant: variant,
            Size: size
        );

        return View(vm);
    }
}
