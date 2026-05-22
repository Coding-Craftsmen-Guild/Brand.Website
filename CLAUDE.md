# Setup rules

These are the conventions for working in this repo. Follow them by default; deviate only with reason.

## Tooling

- Toolchain is pinned in [.mise.toml](.mise.toml). Run `mise install` before doing anything else.
- Run all repo commands through `mise run <task>`, not ad-hoc shells. If a recurring command doesn't have a task, add one to `.mise.toml` instead of documenting it elsewhere.
- Cross-platform scripts under `tools/` are Node.js (Node 22 is in the mise toolchain). Don't introduce bash-only tooling.

## Code style

- Format C# with csharpier: `mise run format`. CI gate is `mise run format:check`.
- No comments unless the *why* is non-obvious. Don't restate what the code already says.
- `Brand.Web` and `brand.web` are placeholder names. To rename, use `mise run rename-project <NewName>` — never hand-edit folder/csproj names.

## Database

- Default DB is SQLite, configured in [appsettings.json](Brand.Web/appsettings.json) via `umbracoDbDSN` + `|DataDirectory|`.
- The DB file lives at `./data/Umbraco.sqlite.db` (host bind mount from both compose files). `./data/` is gitignored — never commit it.
- Resetting the DB = stopping the stack and deleting `./data/Umbraco.sqlite.db*` (3 files: `.db`, `.db-shm`, `.db-wal`).
- SQLite means single-instance only. If horizontal scaling becomes a requirement, switch the connection string to SQL Server / PostgreSQL before scaling `web`.

## Docker

- `docker-compose.yml` is the base. `docker-compose.override.yml` is picked up automatically and switches to the `dev` build target with `dotnet watch` + source bind mount.
- The data directory uses a **host bind mount** (`./data`) in both files — this is intentional so the SQLite file is inspectable. Logs and media remain named volumes.
- Don't bake runtime artefacts (DB, logs, media, schemas) into the image — they're already excluded via [.dockerignore](.dockerignore).

## Umbraco specifics

- `UpgradeUnattended` is on, so migrations apply on boot.
- Razor compile-on-build/publish is disabled by design (see comment in the csproj). Don't re-enable without understanding the InMemoryAuto ModelsMode implication.
- Generated schema files (`appsettings-schema*.json`, `umbraco-package-schema.json`) are gitignored — they regenerate on build.

## What not to commit

- `./data/` — runtime DB and Umbraco data
- `*.sqlite.db`, `*.sqlite.db-shm`, `*.sqlite.db-wal`
- `Brand.Web/umbraco/Logs/` and `Brand.Web/wwwroot/media/`
- Secrets of any kind. There are no env-var files checked in; add them to `.mise.local.toml` (gitignored) if you need per-developer overrides.
