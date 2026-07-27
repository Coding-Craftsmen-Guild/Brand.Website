# Brand.Web

Umbraco CMS site (.NET 10, Umbraco 17), runnable host-native or in Docker. SQLite is the default database; in local dev the files live on the host under `./data/` so the DB is easy to inspect, back up, and reset.

> The folder and assembly are named `Brand.Web` as a placeholder. Use `mise run clone-project <NewName> <DestinationPath>` to spin up a new project from this template — it copies the tracked tree, renames the placeholder, and `git init`s a fresh repo at the destination.

## Quick start

Prerequisites: [mise](https://mise.jdx.dev/), Docker Desktop (only if you want the containerised flow).

```sh
mise install        # installs .NET 10 SDK + Node 22 declared in .mise.toml
mise run setup      # restores .NET local tools (csharpier)
mise run dev        # host-native: dotnet watch on Brand.Web
# - or -
mise run docker:up  # containerised: dev image with dotnet watch, http://localhost:28080
```

First boot installs Umbraco unattended (dev admin `admin@local` / `LocalDev1234!`, see [appsettings.Development.json](Brand.Web/appsettings.Development.json)). The unattended-upgrade flag is on, so subsequent boots auto-apply migrations.

## Project layout

```
Brand.Web/           ASP.NET / Umbraco project
  Client/              Vite + Tailwind v4 client sources
  Views/               Razor views
  wwwroot/             static assets (media/ is volume-mounted; dist/ is Vite output)
  umbraco/Data/        runtime data folder (bind-mounted to ./data/ in dev)
Brand.Core/          domain: doctype .config sources, ViewComponents, services
data/                  dev SQLite DB lives here (host bind mount, gitignored)
artifacts/             `mise run publish` output (gitignored)
tools/                 repo automation (mise tasks call into here)
Dockerfile             multi-stage: build (mise-driven) / dev / runtime
docker-compose.yml           production: expose-only, named volumes, backup sidecar
docker-compose.override.yml  picked up automatically for dev (dotnet watch + bind mounts + :28080)
docker-compose.local.yml     opt-in port override (28081) — `docker compose -f ... -f ...`
```

## Database

SQLite is configured in [appsettings.json](Brand.Web/appsettings.json) via Umbraco's `umbracoDbDSN` with `|DataDirectory|` substitution.

- **Dev**: `docker-compose.override.yml` binds `./data` on the host to the container's Umbraco Data folder, so the DB file is at `./data/Umbraco.sqlite.db`. Host-native `mise run dev` uses `Brand.Web/umbraco/Data/Umbraco.sqlite.db` instead.
- **Prod**: `docker-compose.yml` uses the named `umbraco-data` volume — no host bind, and the `cloud-cli` backup sidecar mounts the same volume.

To reset dev: stop the stack and delete the file (and its `-shm` / `-wal` companions). Do **not** commit `./data/` — it's already gitignored.

SQLite is single-instance only. If you ever scale `web` past one replica, switch to SQL Server or PostgreSQL by updating the connection string in `appsettings.json`.

## Common tasks

All tasks are defined in [.mise.toml](.mise.toml):

| Task | Purpose |
| --- | --- |
| `mise run dev` | host-native hot reload (fastest iteration) |
| `mise run build` | debug build |
| `mise run publish` | Release publish into `artifacts/publish` — the same task the Docker build stage runs |
| `mise run usync:bundle` | flatten `Brand.Core/**/*.config` into `uSync/v17/ContentTypes/` + `Dictionary/` |
| `mise run format` | csharpier + Prettier format |
| `mise run format:check` | formatting verify (CI) |
| `mise run docker:up` | build + start the compose stack |
| `mise run docker:down` | stop the stack |
| `mise run docker:logs` | tail the `web` container |
| `mise run clone-project <Name> <Dest>` | clone this template to `<Dest>`, rename `Brand.Web` → `<Name>.Web`, `git init` a fresh repo |

## Cloning the template into a new project

Run once, with the name you want and the path for the new repo:

```sh
mise run clone-project Acme.Site ../acme-site
```

This:

1. Copies the tracked tree (`git archive HEAD`) into `<DestinationPath>` — no `.git`, `bin/`, `obj/`, `node_modules/`, or runtime data.
2. Rewrites `Brand.Web` / `brand.web` references in `*.csproj`, `*.toml`, `Dockerfile`, `docker-compose*.yml`, `.gitignore`, `.dockerignore`, `README.md`, `CLAUDE.md`, etc., then renames the `Brand.Web/` folder and `.csproj`.
3. Initialises a fresh git repo at the destination (no commit — review and commit yourself).

Afterwards: `cd <DestinationPath> && mise install && mise run setup && mise run build`.
