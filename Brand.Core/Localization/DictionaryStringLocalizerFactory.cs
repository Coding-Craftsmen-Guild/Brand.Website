using Microsoft.Extensions.Localization;

namespace Brand.Core.Localization;

// Bridges MVC's DataAnnotations localization to our single dictionary-backed store.
// AddDataAnnotationsLocalization calls Create(type) once per model type; the type
// is irrelevant here because dictionary ItemKeys are one global flat namespace, so
// every Create(...) returns the same DictionaryStringLocalizer. The provider lambda
// (DataAnnotationLocalizerProvider = (t, f) => f.Create(t)) routes [Display(Name)]
// and every ErrorMessage through it.
public sealed class DictionaryStringLocalizerFactory(DictionaryStringLocalizer localizer)
    : IStringLocalizerFactory
{
    public IStringLocalizer Create(Type resourceSource) => localizer;

    public IStringLocalizer Create(string baseName, string location) => localizer;
}
