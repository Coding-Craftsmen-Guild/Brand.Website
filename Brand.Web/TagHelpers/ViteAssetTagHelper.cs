using System.Text;
using Microsoft.AspNetCore.Razor.TagHelpers;

namespace Brand.Web.TagHelpers;

[HtmlTargetElement("vite-asset", TagStructure = TagStructure.WithoutEndTag)]
public sealed class ViteAssetTagHelper : TagHelper
{
    private readonly IWebHostEnvironment env;
    private readonly ViteManifest manifest;

    public ViteAssetTagHelper(IWebHostEnvironment env, ViteManifest manifest)
    {
        this.env = env;
        this.manifest = manifest;
    }

    [HtmlAttributeName("entry")]
    public string Entry { get; set; }

    [HtmlAttributeName("dev-server")]
    public string DevServer { get; set; } = "http://localhost:5173";

    public override void Process(TagHelperContext context, TagHelperOutput output)
    {
        output.TagName = null;

        if (string.IsNullOrEmpty(Entry))
        {
            return;
        }

        var sb = new StringBuilder();

        if (env.IsDevelopment())
        {
            sb.Append("<script type=\"module\" src=\"")
                .Append(DevServer)
                .Append("/@vite/client\"></script>\n");
            sb.Append("<script type=\"module\" src=\"")
                .Append(DevServer)
                .Append('/')
                .Append(Entry)
                .Append("\"></script>");
        }
        else
        {
            var entry = manifest.Get(Entry);
            if (entry == null)
            {
                output.Content.SetHtmlContent(
                    $"<!-- vite-asset: no manifest entry for '{Entry}' -->"
                );
                return;
            }

            if (entry.Css != null)
            {
                foreach (var css in entry.Css)
                {
                    sb.Append("<link rel=\"stylesheet\" href=\"/dist/")
                        .Append(css)
                        .Append("\">\n");
                }
            }

            if (entry.Imports != null)
            {
                foreach (var import in entry.Imports)
                {
                    var dep = manifest.Get(import);
                    if (dep?.File != null)
                    {
                        sb.Append("<link rel=\"modulepreload\" href=\"/dist/")
                            .Append(dep.File)
                            .Append("\">\n");
                    }
                }
            }

            sb.Append("<script type=\"module\" src=\"/dist/")
                .Append(entry.File)
                .Append("\"></script>");
        }

        output.Content.SetHtmlContent(sb.ToString());
    }
}
