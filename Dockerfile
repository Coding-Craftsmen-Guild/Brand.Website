# syntax=docker/dockerfile:1.7

ARG DOTNET_VERSION=10.0

# ---------- base ----------
# Shared runtime layer: writable Umbraco paths + non-root ownership.
FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION} AS base
WORKDIR /app

USER root
RUN mkdir -p /app/umbraco/Data /app/umbraco/Logs /app/wwwroot/media \
 && chown -R $APP_UID:$APP_UID /app

ENV DOTNET_RUNNING_IN_CONTAINER=true \
    ASPNETCORE_URLS=http://+:8080

EXPOSE 8080

# ---------- build ----------
# Restore + publish in the SDK image.
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS build
WORKDIR /src

# Restore layer caches on csproj + central package props only.
COPY Directory.Packages.props ./
COPY Brand.Web/Brand.Web.csproj ./Brand.Web/
COPY Brand.Core/Brand.Core.csproj ./Brand.Core/
RUN dotnet restore Brand.Web/Brand.Web.csproj

COPY Brand.Web/ ./Brand.Web/
COPY Brand.Core/ ./Brand.Core/
RUN dotnet publish Brand.Web/Brand.Web.csproj \
    -c Release \
    -o /app/publish \
    --no-restore \
    /p:UseAppHost=false

# ---------- dev ----------
# Used by docker-compose.override.yml. Source is bind-mounted in;
# dotnet watch reloads on edit.
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS dev
WORKDIR /src

ENV DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    ASPNETCORE_ENVIRONMENT=Development \
    ASPNETCORE_URLS=http://+:8080 \
    DOTNET_USE_POLLING_FILE_WATCHER=1

EXPOSE 8080

# Default command — compose overrides this via `command:`, but `docker run --target dev` also works.
# CMD (not ENTRYPOINT) so a compose-level command cleanly replaces it instead of appending.
# `--no-launch-profile` is forwarded to `dotnet run` so launchSettings.json's HTTPS/applicationUrl
# don't override the container's ASPNETCORE_URLS env (no HTTPS dev cert inside the container).
CMD ["dotnet", "watch", "--non-interactive", "--project", "Brand.Web/Brand.Web.csproj", "run", "--no-launch-profile"]

# ---------- runtime ----------
# Production image: small aspnet base + published output, non-root.
FROM base AS runtime
WORKDIR /app

COPY --from=build --chown=$APP_UID:$APP_UID /app/publish ./

USER $APP_UID

ENV ASPNETCORE_ENVIRONMENT=Production

ENTRYPOINT ["dotnet", "Brand.Web.dll"]
