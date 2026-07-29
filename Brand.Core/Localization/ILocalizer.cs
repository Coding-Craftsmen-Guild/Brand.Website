namespace Brand.Core.Localization;

// App-facing read API for dictionary text, used from C# (controllers, services) and
// Razor (via the @Html.T helper). A thin wrapper over the dictionary-backed
// IStringLocalizer so the whole app shares one store and one "miss -> key" fallback.
public interface ILocalizer
{
    string this[string key] { get; }

    string T(string key);

    string T(string key, params object[] args);
}
