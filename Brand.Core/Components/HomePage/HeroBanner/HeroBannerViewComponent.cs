using Brand.Core.Models;
using Microsoft.AspNetCore.Mvc;
using Umbraco.Cms.Core.Models;

namespace Brand.Core.Components.HomePage.HeroBanner;

public sealed record HeroBannerViewModel(
    string Title,
    string Text,
    MediaWithCrops Background,
    IEnumerable<Link> Buttons
);

public sealed class HeroBannerViewComponent : ViewComponent
{
    public IViewComponentResult Invoke(Models.HeroBanner source)
    {
        var vm = new HeroBannerViewModel(
            Title: source.Title,
            Text: source.Text,
            Background: source.Background,
            Buttons: source.Buttons
        );

        return View(vm);
    }
}
