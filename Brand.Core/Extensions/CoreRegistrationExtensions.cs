using Brand.Core.Notifications;
using Umbraco.Cms.Core.Notifications;

namespace Brand.Core.Extensions;

public static class CoreRegistrationExtensions
{
    public static IUmbracoBuilder RegisterCore(this IUmbracoBuilder builder)
    {
        builder.AddNotificationAsyncHandler<
            UmbracoApplicationStartedNotification,
            EnsurePageTemplatesHandler
        >();

        return builder;
    }
}
