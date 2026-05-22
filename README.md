# Brand.Web

Umbraco CMS site (.NET 10, Umbraco 17), runnable host-native or in Docker. SQLite is the default database; files live on the host under `./data/` so the DB is easy to inspect, back up, and reset.

> The folder and assembly are named `Brand.Web` as a placeholder. Run `mise run rename-project <NewName>` once to rename everything.

## Quick start

Prerequisites: [mise](https://mise.jdx.dev/), Docker Desktop (only if you want the containerised flow).

```sh
mise install        # installs .NET 10 SDK + Node 22 declared in .mise.toml
mise run setup      # restores .NET local tools (csharpier)
mise run dev        # host-native: dotnet watch on Brand.Web
# - or -
mise run docker:up  # containerised: dev image with dotnet watch, http://localhost:28080
```

First boot lands you in the Umbraco install wizard. The unattended-upgrade flag is on, so subsequent boots auto-apply migrations.

## Project layout

```
Brand.Web/           ASP.NET / Umbraco project
  Views/               Razor views
  wwwroot/             static assets (media/ is volume-mounted)
  umbraco/Data/        runtime data folder (bind-mounted to ./data/)
data/                  SQLite DB lives here (host bind mount, gitignored)
tools/                 repo automation (mise tasks call into here)
Dockerfile             multi-stage: base / build / dev / runtime
docker-compose.yml         prod-ish defaults
docker-compose.override.yml  picked up automatically for dev (dotnet watch + bind mounts)
docker-compose.local.yml     opt-in port override (8090) — `docker compose -f ... -f ...`
```

## Database

SQLite is configured in [appsettings.json](Brand.Web/appsettings.json) via Umbraco's `umbracoDbDSN` with `|DataDirectory|` substitution. Both compose files bind `./data` on the host to the container's Umbraco Data folder, so the DB file is at:

```
./data/Umbraco.sqlite.db
```

To reset: stop the stack and delete the file (and its `-shm` / `-wal` companions). Do **not** commit `./data/` — it's already gitignored.

SQLite is single-instance only. If you ever scale `web` past one replica, switch to SQL Server or PostgreSQL by updating the connection string in `appsettings.json`.

## Common tasks

All tasks are defined in [.mise.toml](.mise.toml):

| Task | Purpose |
| --- | --- |
| `mise run dev` | host-native hot reload (fastest iteration) |
| `mise run build` | debug build |
| `mise run format` | csharpier format |
| `mise run format:check` | csharpier verify (CI) |
| `mise run docker:up` | build + start the compose stack |
| `mise run docker:down` | stop the stack |
| `mise run docker:logs` | tail the `web` container |
| `mise run rename-project <Name>` | rename `Brand.Web` → `<Name>.Web` everywhere |

## Renaming the project

Run once, with the actual name you want:

```sh
mise run rename-project Acme.Site
```

This rewrites references in `*.csproj`, `*.toml`, `Dockerfile`, `docker-compose*.yml`, `.gitignore`, `.dockerignore`, `README.md`, and `CLAUDE.md`, then renames the `Brand.Web/` folder and `.csproj`. `bin/` and `obj/` are wiped. Run `mise run restore && mise run build` afterwards.
