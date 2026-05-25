using OpenIddict.Server.AspNetCore;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

builder.CreateUmbracoBuilder().AddBackOffice().AddWebsite().AddComposers().Build();

if (builder.Environment.IsDevelopment())
{
    // Umbraco's OpenIddict server requires HTTPS by default. The dev container serves
    // plain HTTP on :28080, so allow insecure transport in Development only.
    builder.Services.PostConfigure<OpenIddictServerAspNetCoreOptions>(options =>
    {
        options.DisableTransportSecurityRequirement = true;
    });
}

WebApplication app = builder.Build();

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
