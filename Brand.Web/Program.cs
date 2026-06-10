using Brand.Core.Extensions;
using Brand.Web.TagHelpers;
using Microsoft.AspNetCore.HttpOverrides;
using OpenIddict.Server.AspNetCore;
using TailwindMerge.Extensions;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

builder.CreateUmbracoBuilder().AddBackOffice().AddWebsite().AddComposers().RegisterCore().Build();

builder.Services.AddSingleton<ViteManifest>();
builder.Services.AddTailwindMerge();

if (builder.Environment.IsDevelopment())
{
    // Umbraco's OpenIddict server requires HTTPS by default. The dev container serves
    // plain HTTP on :28080, so allow insecure transport in Development only.
    builder.Services.PostConfigure<OpenIddictServerAspNetCoreOptions>(options =>
    {
        options.DisableTransportSecurityRequirement = true;
    });
}
else
{
    // In hosted environments we run behind a TLS-terminating reverse proxy (the
    // platform edge forwards plain HTTP to Kestrel on :8080). Honor the proxy's
    // X-Forwarded-Proto so the app sees the original request as HTTPS — otherwise
    // OpenIddict rejects backoffice auth with ID2083 ("only accepts HTTPS requests").
    // The proxy IP is dynamic on a PaaS, so clear the known-proxy/network allowlists.
    builder.Services.Configure<ForwardedHeadersOptions>(options =>
    {
        options.ForwardedHeaders =
            ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedFor;
        options.KnownIPNetworks.Clear();
        options.KnownProxies.Clear();
    });
}

WebApplication app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    // Rewrite the request scheme from X-Forwarded-Proto before Umbraco/OpenIddict
    // run, so they observe the original HTTPS request behind the proxy.
    app.UseForwardedHeaders();
}

await app.BootUmbracoAsync();

app.UseUmbraco()
    .WithMiddleware(u =>
    {
        u.UseBackOffice();
        u.UseWebsite();
    })
    .WithEndpoints(u =>
    {
        u.UseBackOfficeEndpoints();
        u.UseWebsiteEndpoints();
    });

await app.RunAsync();
