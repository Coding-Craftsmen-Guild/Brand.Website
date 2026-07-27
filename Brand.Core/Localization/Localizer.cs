using Microsoft.Extensions.Localization;

namespace Brand.Core.Localization;

// Wraps the same dictionary-backed IStringLocalizer that DataAnnotations uses, so a
// key resolves identically whether it's read from a view, a controller, or a
// service. Returns the localized value (or the key itself on a miss).
public sealed class Localizer(IStringLocalizer localizer) : ILocalizer
{
    public string this[string key] => localizer[key].Value;

    public string T(string key) => localizer[key].Value;

    public string T(string key, params object[] args) => localizer[key, args].Value;
}
