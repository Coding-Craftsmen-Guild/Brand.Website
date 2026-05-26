using Brand.Core.Models;
using Microsoft.AspNetCore.Mvc;
using Umbraco.Cms.Core.Models;

namespace Brand.Core.Compositions.Footer;

public sealed record FooterViewModel(MediaWithCrops Logo);

public sealed class FooterViewComponent : ViewComponent
{
    public IViewComponentResult Invoke(IFooter source)
    {
        var vm = new FooterViewModel(Logo: source.FooterLogo);
        return View(vm);
    }
}
