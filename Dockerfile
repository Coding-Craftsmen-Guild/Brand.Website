# syntax=docker/dockerfile:1

ARG DOTNET_VERSION=10.0

# ---------- build ----------
# mise is the single source of truth for build steps (tool versions, uSync bundling,
# client build, NuGet restore, publish). Docker's only job in this stage is to host
# the environment mise runs in and hand the published output to the runtime stage —
# no npm/dotnet/usync command is written twice.
FROM debian:bookworm-slim AS build
WORKDIR /src

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl bash ca-certificates git libicu72 \
    && rm -rf /var/lib/apt/lists/*

RUN curl https://mise.run | sh \
    && mv /root/.local/bin/mise /usr/local/bin/mise

# Non-interactive builds can't answer mise's config-trust / confirmation prompts.
ENV MISE_YES=1

# Toolchain layer: only invalidated when tool versions in .mise.toml change.
COPY .mise.toml ./
RUN mise install

# Restore/install layer: only invalidated when dependency manifests change, so an
# app source-only edit doesn't force a re-download of NuGet/npm packages.
COPY Directory.Packages.props ./
COPY Brand.Web/Brand.Web.csproj ./Brand.Web/
COPY Brand.Core/Brand.Core.csproj ./Brand.Core/
COPY Brand.Web/package.json Brand.Web/package-lock.json ./Brand.Web/
RUN mise run restore
RUN --mount=type=cache,target=/root/.npm mise run client:install

# Full source, then the one mise task that owns the rest of the pipeline. `publish`
# depends on usync:bundle + client:build + restore, so this is deliberately the only
# build RUN left — letting mise re-walk its own dependency graph here (instead of
# re-listing each step) means every step still runs exactly once per named task, and
# restore/client:install are warm no-ops thanks to the layer above.
COPY . .
RUN --mount=type=cache,target=/root/.npm mise run publish

# ---------- dev ----------
# Used by docker-compose.override.yml: source is bind-mounted in and dotnet watch
# reloads on edit. No build steps run at image-build time — there's nothing to build
# until source is mounted at container start — so this stays a thin SDK shell.
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS dev
WORKDIR /src

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    ASPNETCORE_URLS=http://+:8080 \
    DOTNET_USE_POLLING_FILE_WATCHER=1
EXPOSE 8080

# CMD (not ENTRYPOINT) so a compose-level command cleanly replaces it instead of
# appending. `--no-launch-profile` keeps launchSettings.json's HTTPS/applicationUrl
# from overriding the container's ASPNETCORE_URLS (no HTTPS dev cert in-container).
CMD ["dotnet", "watch", "--non-interactive", "--project", "Brand.Web/Brand.Web.csproj", "run", "--no-launch-profile"]

# ---------- runtime ----------
# Production image: aspnet base + published output, non-root. ASPNETCORE_ENVIRONMENT
# is intentionally NOT set here — docker-compose.yml supplies it locally and Coolify
# supplies it in production, per environment, never baked into the image.
FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION} AS runtime
WORKDIR /app

# Pre-create the Umbraco writable paths owned by the non-root app user — compose/
# Coolify mount volumes here, which would otherwise be root-owned and unwritable.
RUN mkdir -p umbraco/Data umbraco/Logs wwwroot/media && chown -R $APP_UID:$APP_UID /app

COPY --from=build --chown=$APP_UID:$APP_UID /src/artifacts/publish ./

USER $APP_UID
ENTRYPOINT ["dotnet", "Brand.Web.dll"]
