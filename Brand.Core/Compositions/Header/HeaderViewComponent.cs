using Brand.Core.Models;
using Microsoft.AspNetCore.Mvc;
using Umbraco.Cms.Core.Models;

namespace Brand.Core.Compositions.Header;

public sealed record HeaderViewModel(MediaWithCrops Logo);

public sealed class HeaderViewComponent : ViewComponent
{
    public IViewComponentResult Invoke(IHeader source)
    {
        var vm = new HeaderViewModel(Logo: source.HeaderLogo);
        return View(vm);
    }
}
