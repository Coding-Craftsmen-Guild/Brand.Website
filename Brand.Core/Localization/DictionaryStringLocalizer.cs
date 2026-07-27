using System.Globalization;
using Microsoft.Extensions.Localization;
using Umbraco.Cms.Core.Dictionary;

namespace Brand.Core.Localization;

// The single localization store: an IStringLocalizer backed by Umbraco's culture
// dictionary. Every read path — DataAnnotations (via the factory below), ILocalizer
// (C#) and @Html.T (Razor) — funnels through here so "miss falls back to the key"
// is defined exactly once. CreateDictionary() is itself culture-aware (it reads
// CurrentUICulture and does parent-culture fallback), so no culture is threaded in.
// Umbraco's indexer returns string.Empty (not null) on a miss; we treat empty as
// "not found" and surface the key, so missing translations are visible, not blank.
public sealed class DictionaryStringLocalizer(ICultureDictionaryFactory dictionaryFactory)
    : IStringLocalizer
{
    public LocalizedString this[string name]
    {
        get
        {
            var value = dictionaryFactory.CreateDictionary()[name];
            return string.IsNullOrEmpty(value)
                ? new LocalizedString(name, name, resourceNotFound: true)
                : new LocalizedString(name, value, resourceNotFound: false);
        }
    }

    public LocalizedString this[string name, params object[] arguments]
    {
        get
        {
            var localized = this[name];
            var formatted = string.Format(CultureInfo.CurrentCulture, localized.Value, arguments);
            return new LocalizedString(name, formatted, localized.ResourceNotFound);
        }
    }

    // The dictionary has no efficient "all keys" enumeration and no consumer needs
    // it (DataAnnotations only ever indexes by key), so this returns nothing.
    public IEnumerable<LocalizedString> GetAllStrings(bool includeParentCultures) =>
        Enumerable.Empty<LocalizedString>();
}
