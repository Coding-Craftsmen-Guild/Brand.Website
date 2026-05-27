using System.Text.Json;
using System.Text.Json.Serialization;

namespace Brand.Web.TagHelpers;

public sealed class ViteManifest
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    private readonly Dictionary<string, ViteManifestEntry> entries;

    public ViteManifest(IWebHostEnvironment env)
    {
        var path = Path.Combine(env.WebRootPath ?? string.Empty, "dist", ".vite", "manifest.json");
        if (File.Exists(path))
        {
            var json = File.ReadAllText(path);
            entries =
                JsonSerializer.Deserialize<Dictionary<string, ViteManifestEntry>>(json, JsonOpts)
                ?? new Dictionary<string, ViteManifestEntry>();
        }
        else
        {
            entries = new Dictionary<string, ViteManifestEntry>();
        }
    }

    public ViteManifestEntry Get(string key) =>
        entries.TryGetValue(key, out var entry) ? entry : null;
}

public sealed record ViteManifestEntry
{
    [JsonPropertyName("file")]
    public string File { get; init; }

    [JsonPropertyName("css")]
    public string[] Css { get; init; }

    [JsonPropertyName("imports")]
    public string[] Imports { get; init; }

    [JsonPropertyName("isEntry")]
    public bool IsEntry { get; init; }
}
