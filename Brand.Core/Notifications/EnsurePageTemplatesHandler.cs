using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Events;
using Umbraco.Cms.Core.Notifications;
using Umbraco.Cms.Core.Services;
using Umbraco.Extensions;

namespace Brand.Core.Notifications;

// Templates are managed manually rather than through uSync (uSync 17.3.2 can't
// import templates on Umbraco 17 — its serializer fails whether the .cshtml is
// present or not). After startup, for every doc type that has a physical view at
// Views/{Alias}.cshtml, make sure a matching Template entity exists and is wired
// up as that doc type's default (and allowed) template.
public sealed class EnsurePageTemplatesHandler(
    IContentTypeService contentTypeService,
    ITemplateService templateService,
    IHostEnvironment environment,
    ILogger<EnsurePageTemplatesHandler> logger
) : INotificationAsyncHandler<UmbracoApplicationStartedNotification>
{
    public async Task HandleAsync(
        UmbracoApplicationStartedNotification notification,
        CancellationToken cancellationToken
    )
    {
        foreach (var contentType in contentTypeService.GetAll())
        {
            var alias = contentType.Alias.ToFirstUpper();
            var viewPath = Path.Combine(environment.ContentRootPath, "Views", $"{alias}.cshtml");
            if (!File.Exists(viewPath))
            {
                continue;
            }

            var template = await templateService.GetAsync(alias);
            if (template is null)
            {
                // The view carries no "Layout = ..." line (the default layout is set in
                // _ViewStart.cshtml), so Umbraco won't try to resolve a master template
                // from its content and the create succeeds with the real view content.
                var content = await File.ReadAllTextAsync(viewPath, cancellationToken);
                var attempt = await templateService.CreateAsync(
                    alias,
                    alias,
                    content,
                    Constants.Security.SuperUserKey
                );
                if (!attempt.Success)
                {
                    logger.LogWarning(
                        "Could not create template '{Alias}': {Status}",
                        alias,
                        attempt.Status
                    );
                    continue;
                }

                template = attempt.Result;
                logger.LogInformation("Created template '{Alias}' from its view file.", alias);
            }

            if (contentType.DefaultTemplate?.Id == template.Id)
            {
                continue;
            }

            var allowed = contentType.AllowedTemplates?.ToList() ?? [];
            if (allowed.All(t => t.Id != template.Id))
            {
                allowed.Add(template);
            }

            contentType.AllowedTemplates = allowed;
            contentType.SetDefaultTemplate(template);
            await contentTypeService.UpdateAsync(contentType, Constants.Security.SuperUserKey);
            logger.LogInformation(
                "Linked template '{Alias}' to doc type '{DocType}'.",
                alias,
                contentType.Alias
            );
        }
    }
}
