# Setup rules

These are the conventions for working in this repo. Follow them by default; deviate only with reason.

## Tooling

- Toolchain is pinned in [.mise.toml](.mise.toml). Run `mise install` before doing anything else.
- Run all repo commands through `mise run <task>`, not ad-hoc shells. If a recurring command doesn't have a task, add one to `.mise.toml` instead of documenting it elsewhere.
- Scripts under `tools/` are bash (`*.sh`), invoked via `bash tools/<name>.sh` from mise tasks (see `rename-project`). On Windows, bash comes from Git Bash. Don't introduce other scripting languages for tooling.

## Code style

- Format C# with csharpier: `mise run format`. CI gate is `mise run format:check`.
- No comments unless the *why* is non-obvious. Don't restate what the code already says.
- `Brand.Web` and `brand.web` are placeholder names. To rename, use `mise run rename-project <NewName>` — never hand-edit folder/csproj names.

## Database

- Default DB is SQLite, configured in [appsettings.json](Brand.Web/appsettings.json) via `umbracoDbDSN` + `|DataDirectory|`.
- The DB file lives at `./data/Umbraco.sqlite.db` (host bind mount from both compose files). `./data/` is gitignored — never commit it.
- Resetting the DB = stopping the stack and deleting `./data/Umbraco.sqlite.db*` (3 files: `.db`, `.db-shm`, `.db-wal`).
- SQLite means single-instance only. If horizontal scaling becomes a requirement, switch the connection string to SQL Server / PostgreSQL before scaling `web`.

### First-boot install (dev only)

- [appsettings.Development.json](Brand.Web/appsettings.Development.json) enables `Umbraco:CMS:Unattended:InstallUnattended` and seeds an admin user. This is required: with a `|DataDirectory|` SQLite connection string pre-configured, Umbraco's runtime state machine routes a missing DB to `BootFailed` (reason `InstallMissingDatabase`) instead of showing the install wizard — so unattended install is the only way to bootstrap dev.
- Dev admin: `admin@local` / `LocalDev1234!`. Change before exposing the dev container off-localhost.
- Production ([appsettings.json](Brand.Web/appsettings.json)) intentionally has **no** unattended config — first prod boot must be installed deliberately (env-var override or manual config).

## Docker

- `docker-compose.yml` is the base. `docker-compose.override.yml` is picked up automatically and switches to the `dev` build target with `dotnet watch` + source bind mount.
- The data directory uses a **host bind mount** (`./data`) in both files — this is intentional so the SQLite file is inspectable. Logs and media remain named volumes.
- Don't bake runtime artefacts (DB, logs, media, schemas) into the image — they're already excluded via [.dockerignore](.dockerignore).

## Umbraco specifics

- `UpgradeUnattended` is on, so migrations apply on boot.
- Razor compile-on-build/publish is disabled by design (see comment in the csproj). Don't re-enable without understanding the InMemoryAuto ModelsMode implication.
- Generated schema files (`appsettings-schema*.json`, `umbraco-package-schema.json`) are gitignored — they regenerate on build.

## uSync

uSync folder is `Brand.Web/uSync/v17/`. Behaviour splits by environment.

- **Dev** ([appsettings.Development.json](Brand.Web/appsettings.Development.json)): `ImportAtStartup: "All"` + `ExportOnSave: "Settings"`. `ContentHandler` and `MediaHandler` are disabled. `ContentTypeHandler` and `DictionaryHandler` are set to `Actions: "Import"` — they apply on startup but never write back, because doctypes and dictionary entries are code-first (authored in source, bundled into the folder by a build step — pattern TBD). Don't re-enable content/media in dev.
- **Prod** ([appsettings.json](Brand.Web/appsettings.json)): `ImportAtStartup: "None"` + `ExportOnSave: "All"`. Every backoffice save (content, media, dictionary, schema) writes to disk. Operator triggers import manually after each deploy.

Tracked vs gitignored in `Brand.Web/uSync/v17/`:
- Tracked: `DataTypes/`, `Languages/`, `MediaTypes/`, `MemberTypes/`, `RelationTypes/`, `Templates/`.
- Gitignored: `ContentTypes/` (DocumentTypes — code-first), `Dictionary/` (code-first starting items).

Code-first authoring:
- Use the `usync-author` skill at [.claude/skills/usync-author/SKILL.md](.claude/skills/usync-author/SKILL.md). It enforces a mandatory GUID-uniqueness check before assigning any `Key` to a new DocumentType or Dictionary entry.
- Source files live in a sibling folder under `Brand.Web/` — **layout TBD**. Once decided, set `SOURCE_ROOT` in [tools/usync-bundle.sh](tools/usync-bundle.sh) and document the layout in the skill.
- `mise run usync:bundle` merges sources into `Brand.Web/uSync/v17/{ContentTypes,Dictionary}/`. Currently a stub — exits non-zero with instructions until the layout is defined.

Prod capture volume: `docker-compose.yml` bind-mounts `./usync:/app/uSync`, so prod runtime captures persist on the host and are inspectable. The folder is gitignored as `/usync/`.

- **First-deploy seeding** (run once before `docker compose up` in prod): `mkdir -p ./usync && cp -r Brand.Web/uSync/. ./usync/`. Otherwise the empty bind mount shadows the image's shipped `uSync/v17/` and a fresh import has nothing to read.
- **Subsequent prod deploys** with updated shipped schema: the bind mount keeps shadowing the new image; updated shipped files must be merged into `./usync/v17/` before triggering import. Captures under `Content/`, `Media/`, `Dictionary/`, `ContentTypes/` should be preserved during the merge. A real deploy script is a follow-up.
- **Replicate prod to another env**: copy or rsync `./usync/` to the target host.
- **Host bind permissions**: the dotnet runtime user inside the container must own (or have group write on) `./usync/`. If exports silently no-op in prod, check `ls -la ./usync` first.

## What not to commit

- `./data/` — runtime DB and Umbraco data
- `*.sqlite.db`, `*.sqlite.db-shm`, `*.sqlite.db-wal`
- `Brand.Web/umbraco/Logs/` and `Brand.Web/wwwroot/media/`
- `Brand.Web/uSync/v17/ContentTypes/` and `Brand.Web/uSync/v17/Dictionary/` — code-first artifacts
- `/usync/` — prod uSync runtime capture volume
- Secrets of any kind. There are no env-var files checked in; add them to `.mise.local.toml` (gitignored) if you need per-developer overrides.
