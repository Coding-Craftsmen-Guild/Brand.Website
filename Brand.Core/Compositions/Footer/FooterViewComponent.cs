using Brand.Core.Models;
using Microsoft.AspNetCore.Mvc;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Web.Common;

namespace Brand.Core.Compositions.Footer;

public sealed record FooterViewModel(MediaWithCrops Logo);

public sealed class FooterViewComponent(UmbracoHelper umbracoHelper) : ViewComponent
{
    public IViewComponentResult Invoke()
    {
        var root = umbracoHelper.ContentAtRoot().OfType<IFooter>().FirstOrDefault();

        var vm = new FooterViewModel(Logo: root.FooterLogo);
        
        return View(vm);
    }
}
