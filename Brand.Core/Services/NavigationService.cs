using Brand.Core.Models;
using Umbraco.Cms.Core.Models.PublishedContent;
using Umbraco.Cms.Core.Services.Navigation;
using Umbraco.Cms.Core.Web;
using Umbraco.Cms.Web.Common;
using Umbraco.Extensions;

namespace Brand.Core.Services;

public sealed record NavItem(string Label, string Url, bool IsActive);

public sealed record Crumb(string Label, string Url, bool IsCurrent);

public interface INavigationService
{
    IReadOnlyList<NavItem> GetTopNavigation();

    IReadOnlyList<Crumb> GetBreadcrumbs();
}

public sealed class NavigationService(
    UmbracoHelper umbracoHelper,
    IUmbracoContextAccessor umbracoContextAccessor,
    IDocumentNavigationQueryService navigationQueryService
) : INavigationService
{
    // The design's navigation is a single flat row — the site root plus its immediate
    // children. Deeper pages highlight their section rather than opening a submenu.
    public IReadOnlyList<NavItem> GetTopNavigation()
    {
        var root = umbracoHelper.ContentAtRoot().OfType<Models.HomePage>().FirstOrDefault();
        if (root is null)
        {
            return [];
        }

        var current = CurrentPage();
        var items = new List<NavItem> { new(root.Name, root.Url(), current?.Id == root.Id) };

        if (
            root.HideChildrenFromNavigation
            || !navigationQueryService.TryGetChildrenKeys(root.Key, out var childKeys)
        )
        {
            return items;
        }

        items.AddRange(
            childKeys
                .Select(umbracoHelper.Content)
                .OfType<Page>()
                .Where(page => page.IsPublished() && !page.HideFromNavigation)
                .Select(page => new NavItem(page.Name, page.Url(), IsWithin(current, page)))
        );

        return items;
    }

    // Root-first trail for the current page, so the Standard Banner never carries a
    // hand-maintained breadcrumb list. Walks up via the navigation query service —
    // IPublishedContent.Parent is obsolete and goes away in Umbraco 18.
    public IReadOnlyList<Crumb> GetBreadcrumbs()
    {
        var current = CurrentPage();
        if (current is null)
        {
            return [];
        }

        var trail = new List<IPublishedContent>();
        for (var node = current; node is not null; node = ParentOf(node))
        {
            trail.Add(node);
        }

        trail.Reverse();

        return
        [
            .. trail.Select(node => new Crumb(
                Label: node.Name,
                Url: node.Id == current.Id ? string.Empty : node.Url(),
                IsCurrent: node.Id == current.Id
            )),
        ];
    }

    private IPublishedContent ParentOf(IPublishedContent node) =>
        navigationQueryService.TryGetParentKey(node.Key, out var parentKey) && parentKey.HasValue
            ? umbracoHelper.Content(parentKey.Value)
            : null;

    private IPublishedContent CurrentPage() =>
        umbracoContextAccessor.TryGetUmbracoContext(out var ctx)
            ? ctx.PublishedRequest?.PublishedContent
            : null;

    // Active when the current page *is* the item or sits underneath it. Path is the
    // comma-separated ancestor id list, so a prefix test needs no tree walk.
    private static bool IsWithin(IPublishedContent current, IPublishedContent item) =>
        current is not null
        && (
            current.Id == item.Id
            || current.Path.Split(',').Contains(item.Id.ToString(), StringComparer.Ordinal)
        );
}
