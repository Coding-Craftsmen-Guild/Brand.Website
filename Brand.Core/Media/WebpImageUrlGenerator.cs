using Microsoft.Extensions.DependencyInjection;
using Umbraco.Cms.Core.Media;
using Umbraco.Cms.Core.Models;

namespace Brand.Core.Media;

// Every GetCropUrl call serves JPEG/PNG media as WebP. Wraps the URL generator rather
// than hooking the ImageSharp middleware so the format is part of the HMAC-signed query.
public class WebpImageUrlGenerator(IImageUrlGenerator inner) : IImageUrlGenerator
{
    private static readonly string[] Convertible = [".jpg", ".jpeg", ".png"];

    public IEnumerable<string> SupportedImageFileTypes => inner.SupportedImageFileTypes;

    public string GetImageUrl(ImageUrlGenerationOptions options)
    {
        if (
            options?.ImageUrl is not null
            && options.Format is null
            && IsConvertible(options.ImageUrl)
        )
        {
            options.Format = "webp";
            options.Quality ??= 80;
        }

        // ImageSharp upscales when asked for more pixels than the source has.
        if (
            options is not null
            && options.Height is null
            && options.Width > options.SourceWidth
            && options.SourceWidth > 0
        )
        {
            options.Width = options.SourceWidth;
        }

        return inner.GetImageUrl(options);
    }

    private static bool IsConvertible(string url)
    {
        var path = url.Split('?', '#')[0];
        return Convertible.Any(ext => path.EndsWith(ext, StringComparison.OrdinalIgnoreCase));
    }

    // Call after AddComposers(): the ImageSharp composer registers the generator we wrap.
    public static void Register(IServiceCollection services)
    {
        var existing = services.Last(d => d.ServiceType == typeof(IImageUrlGenerator));
        services.Remove(existing);
        services.Add(
            ServiceDescriptor.Describe(
                typeof(IImageUrlGenerator),
                sp => new WebpImageUrlGenerator(
                    (IImageUrlGenerator)(
                        existing.ImplementationInstance
                        ?? existing.ImplementationFactory?.Invoke(sp)
                        ?? ActivatorUtilities.CreateInstance(sp, existing.ImplementationType)
                    )
                ),
                existing.Lifetime
            )
        );
    }
}
