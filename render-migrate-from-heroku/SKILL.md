---
name: render-migrate-from-heroku
description: "Migrate from Heroku to Render by reading local project files and generating equivalent Render services. Triggers: any mention of migrating from Heroku, moving off Heroku, Heroku to Render migration, or switching from Heroku. Reads Procfile, dependency files, and app config from the local repo. Optionally uses Heroku MCP to enrich with live config vars, add-on details, and dyno sizes. Uses Render MCP or Blueprint YAML to create services."
license: MIT
compatibility: Render MCP server recommended for direct creation and automated verification; not required for the Blueprint path. Heroku MCP server is optional (enhances config var and add-on discovery).
metadata:
  author: Render
  version: "1.4.0"
  category: migration
---

# Heroku to Render Migration

Migrate from Heroku to Render by reading local project files first, then optionally enriching with live Heroku data via MCP.

## Prerequisites Check

Before starting, verify what's available:

1. **Local project files** (required) — confirm the current directory contains a Heroku app (look for `Procfile`, `app.json`, `package.json`, `requirements.txt`, `Gemfile`, `go.mod`, or similar)
2. **Render MCP** (recommended) — check if `list_services` tool is available. Required for MCP Direct Creation (Step 3B) and automated verification (Step 6). Not required for the Blueprint path — the Render CLI and Dashboard handle generation, validation, and deployment.
3. **Heroku MCP** (optional) — check if `list_apps` tool is available

If Render MCP is missing and the user needs it, guide them through setup using the [MCP setup guide](references/mcp-setup.md). If Heroku MCP is missing, note that config var values and add-on plan details will need to be provided manually.

## Migration Workflow

Execute steps in order. Present findings to the user and get confirmation before creating any resources.

### Step 1: Inventory Heroku App

Gather app details from local files first, then supplement with Heroku MCP if available.

#### 1a. Read local project files (always)

Read these files from the repo to determine runtime, commands, and dependencies:

| File | What it tells you |
|---|---|
| `Procfile` | Process types and start commands (`web`, `worker`, `clock`, `release`) |
| `package.json` | Node.js runtime, build scripts, framework deps (Next.js, React, etc.) |
| `requirements.txt` / `Pipfile` / `pyproject.toml` | Python runtime, dependencies (Django, Flask, etc.) |
| `Gemfile` | Ruby runtime, dependencies (Rails, Sidekiq, etc.) |
| `go.mod` | Go runtime |
| `Cargo.toml` | Rust runtime |
| `app.json` | Declared add-ons, env var descriptions, buildpacks |
| `runtime.txt` | Pinned runtime version |
| `static.json` | Static site indicator |
| `yarn.lock` / `pnpm-lock.yaml` | Package manager (affects build command) |

From these files, determine:
- **Runtime** — from dependency files (see the [buildpack mapping](references/buildpack-mapping.md))
- **Runtime version** — from `runtime.txt`, `.node-version`, or `engines` in `package.json`. If pinned, carry it over as an env var (e.g., `PYTHON_VERSION`, `NODE_VERSION`). If not pinned, do not specify a version — never assume or state what Render's default version is.
- **Build command** — from package manager and framework (see the [buildpack mapping](references/buildpack-mapping.md))
- **Start commands** — from `Procfile` entries
- **Process types** — from `Procfile` (web, worker, clock, release)
- **Add-ons needed** — from `app.json` `addons` field, or infer from dependency files (e.g., `pg` in `package.json` suggests Postgres, `redis` suggests Key Value)
- **Static site?** — from `static.json`, SPA framework deps, or static buildpack in `app.json`

#### 1b. Enrich with Heroku MCP (if available)

If the Heroku MCP server is connected, call these tools to fill in details that aren't in the repo. The **dyno size** and **add-on plan slug** are critical — they determine which Render plans to use.

1. `list_apps` — let user select which app to migrate (confirms app name)
2. `get_app_info` — capture: region, stack, buildpacks, **config var names**
3. `list_addons` — capture the **exact add-on plan slug** (e.g., `heroku-postgresql:essential-2`, `heroku-redis:premium-0`). The part after the colon maps to a specific Render plan in the [service mapping](references/service-mapping.md).
4. `ps_list` — capture the **exact dyno size** for each process type (e.g., `Standard-2X`, `Performance-M`). Each dyno size maps to a specific Render plan in the [service mapping](references/service-mapping.md).
5. `pg_info` (if Postgres exists) — capture **Data Size** (actual usage) and the plan's disk allocation. The plan's disk size determines the `diskSizeGB` value in the Blueprint (see the [service mapping](references/service-mapping.md)).

If Heroku MCP is **not** available, ask the user to provide:
- Dyno sizes (or run `heroku ps:type -a <app>` and paste output)
- Add-on plans (or run `heroku addons -a <app>` and paste output)
- Database info (or run `heroku pg:info -a <app>` and paste output — captures plan name, data size, and disk allocation)
- App region (`us` or `eu`)
- Config var names (or run `heroku config -a <app> --shell` and paste output)

If the user cannot provide dyno sizes or add-on plans, use the fallback defaults from the [service mapping](references/service-mapping.md): `starter` for compute, `basic-1gb` for Postgres, `starter` for Key Value.

#### Present summary

```
App: [name] | Region: [region] | Runtime: [node/python/ruby/etc]
Source: [local files | local files + Heroku MCP]
Build command: [inferred from buildpack/deps]
Processes:
  web: [command from Procfile] → Render web service ([mapped-plan])
  worker: [command] → Render background worker ([mapped-plan], Blueprint only)
  clock: [command] → Render cron job ([mapped-plan])
  release: [command] → Append to build command
Add-ons:
  Heroku Postgres ([plan-slug], [disk-size]) → Render Postgres ([mapped-plan], diskSizeGB: [size])
  Heroku Redis ([plan-slug]) → Render Key Value ([mapped-plan])
Config vars: 14 total (list names, not values)
```

### Step 2: Pre-Flight Check

Before creating anything, validate the migration plan and present it to the user. Check for:

1. **Runtime supported?** If buildpack maps to `docker`, warn user they need a Dockerfile
2. **Worker dynos?** Flag these — can be defined in a Blueprint (`type: worker`, minimum plan `starter`), but cannot be created via MCP tools directly
3. **Release phase?** If Procfile has `release:`, suggest appending to build command
4. **Static site?** Check for static buildpack, `static.json`, or SPA framework deps — use `create_static_site` instead of `create_web_service`. See detection rules in the [buildpack mapping](references/buildpack-mapping.md).
5. **Third-party add-ons?** List any add-ons without direct Render equivalents (e.g., Papertrail, SendGrid) — user needs to find alternatives and update env vars
6. **Multiple process types?** If Procfile has >1 entry, each becomes a separate Render service (except `release:`)
7. **Repo URL available?** Verify a Git remote exists:

   ```bash
   git remote -v
   ```

   If no remote exists, stop and guide the user to create a GitHub/GitLab/Bitbucket repo, add it as `origin`, and push before continuing.

   If the URL is SSH format, convert it to HTTPS for service creation and deeplinks:

   | SSH Format | HTTPS Format |
   |---|---|
   | `git@github.com:user/repo.git` | `https://github.com/user/repo` |
   | `git@gitlab.com:user/repo.git` | `https://gitlab.com/user/repo` |
   | `git@bitbucket.org:user/repo.git` | `https://bitbucket.org/user/repo` |

   **Conversion pattern:** Replace `git@<host>:` with `https://<host>/` and remove the `.git` suffix.

8. **Database size?** If Postgres is Premium/large tier, recommend contacting Render support for assisted migration

Look up each Heroku dyno size and add-on plan in the [service mapping](references/service-mapping.md) to determine the correct Render plan. Then present the full plan as a table:

```
MIGRATION PLAN — [app-name]
─────────────────────────────────
CREATE (include only items that apply):
  ✅ Web service ([runtime], [mapped-plan]) — startCommand: [cmd]
     Heroku: [dyno-size] ($X/mo) → Render: [mapped-plan] ($Y/mo)
  ✅ Background worker ([runtime], [mapped-plan]) — startCommand: [cmd]
     Heroku: [dyno-size] ($X/mo) → Render: [mapped-plan] ($Y/mo)
  ✅ Cron job ([mapped-plan]) — schedule: [cron expr] — command: [cmd]
  ✅ Postgres ([mapped-plan], diskSizeGB: [size])
     Heroku: [plan-slug] ($X/mo) → Render: [mapped-plan] ($Y/mo + storage)
  ✅ Key Value ([mapped-plan])
     Heroku: [plan-slug] ($X/mo) → Render: [mapped-plan] ($Y/mo)

ESTIMATED MONTHLY COST:
  Heroku: $[total]/mo → Render: $[total]/mo
  (Render storage billed separately at $0.30/GB/mo)

METHOD: [Blueprint | MCP Direct Creation]

MANUAL STEPS REQUIRED:
  ⚠️ Custom domain: [domain] — configure after deploy
  ⚠️ Replace add-on: [name] → find alternative

ENV VARS: [N] to migrate, [M] filtered out
DATABASE: [size] — pg_dump/pg_restore required
─────────────────────────────────
Proceed? (y/n)
```

Use the pricing columns in the [service mapping](references/service-mapping.md) to calculate costs. Sum up the Render $/mo for each service, database, and Key Value store. For Postgres, note that storage is billed separately.

Wait for user confirmation before creating any resources.

### Determine Creation Method

After the user approves the pre-flight plan, apply this decision rule. **Default to Blueprint** — only use MCP Direct Creation when every condition below is met.

**Use Blueprint** (the default) when ANY are true:
- Multiple process types (web + worker, web + cron, etc.)
- Databases or Key Value stores needed
- Background workers in the Procfile
- User prefers Infrastructure-as-Code configuration

**Fall back to MCP Direct Creation** ONLY when ALL are true:
- Single web or static site service (one process type)
- No background workers or cron jobs
- No databases or Key Value stores

If unsure, use Blueprint. Most Heroku apps have at least a database, so Blueprint applies to the vast majority of migrations.

### Step 3A: Generate Blueprint (Multi-Service)

This step has three mandatory sub-steps. Complete all three in order.

#### 3A-i. Write render.yaml

Generate a `render.yaml` file and write it to the repo root. See the [Blueprint example](references/blueprint-example.md) for a complete example, the [Blueprint docs](https://render.com/docs/blueprint-spec#projects-and-environments) for usage guidance, and the [Blueprint YAML JSON schema](https://render.com/schema/render.yaml.json) for the full field reference.

**IMPORTANT: Always use the `projects`/`environments` pattern.** The YAML must start with a `projects:` key — never use flat top-level `services:` or `databases:` keys. This groups all migrated resources into a single Render project.

**Set the `plan:` field for each service and database using the mapped Render plan from the [service mapping](references/service-mapping.md).** Look up the Heroku dyno size (from `ps_list`) and add-on plan slug (from `list_addons`) to find the correct Render plan. If the Heroku plan is unknown, use the fallback defaults: `starter` for compute, `basic-1gb` for Postgres, `starter` for Key Value.

**Required Blueprint structure** (always starts with `projects:`):

```yaml
previews:
  generation: off
projects:
  - name: <heroku-app-name>
    environments:
      - name: production
        services:
          - type: web
            name: <app>-web
            runtime: <mapped-runtime>
            plan: <mapped-plan>  # from service mapping, e.g. starter, standard, pro
            buildCommand: <build-cmd>
            startCommand: <web-cmd>
            envVars:
              - key: DATABASE_URL
                fromDatabase:
                  name: <app>-db
                  property: connectionString
              - key: REDIS_URL
                fromService:
                  type: keyvalue
                  name: <app>-cache
                  property: connectionString
              - key: NON_SECRET_VAR
                value: <value>
              - key: SECRET_VAR
                sync: false
          # Include only if worker dyno exists
          - type: worker
            name: <app>-worker
            runtime: <mapped-runtime>
            plan: <mapped-plan>  # same mapping as web dyno size
            buildCommand: <build-cmd>
            startCommand: <worker-cmd>
            envVars:
              - key: NON_SECRET_VAR
                value: <value>
              - key: SECRET_VAR
                sync: false
          # Include only if scheduler/clock exists
          - type: cron
            name: <app>-cron
            runtime: <mapped-runtime>
            plan: <mapped-plan>  # same mapping as web dyno size
            schedule: "<cron-expression>"
            buildCommand: <build-cmd>
            startCommand: <cron-cmd>
            envVars:
              - key: NON_SECRET_VAR
                value: <value>
              - key: SECRET_VAR
                sync: false
          # Include only if Redis add-on exists
          - type: keyvalue
            name: <app>-cache
            plan: <mapped-plan>  # from Key Value mapping
            ipAllowList:
              - source: 0.0.0.0/0
                description: everywhere
        databases:
          # Include only if Postgres add-on exists
          - name: <app>-db
            plan: <mapped-plan>  # from Postgres mapping, e.g. basic-1gb, pro-4gb
            diskSizeGB: <heroku-disk-size>  # carry over from Heroku plan allocation
```

**Key rules:**
- **Set every `plan:` field using the [service mapping](references/service-mapping.md)** — look up the Heroku dyno size or add-on plan and use the mapped Render plan. Never hardcode `starter` without checking the mapping first.
- **Set `diskSizeGB` on databases** — carry over the Heroku disk allocation from the [service mapping](references/service-mapping.md). Round up to 1 or the nearest multiple of 5. Tell the user that Render storage is expandable and they can resize later based on actual usage.
- Always include `previews: { generation: off }` at the root level to disable preview environments by default
- The YAML **must** use the `projects:`/`environments:` pattern — never use flat top-level `services:`
- Use `fromDatabase` for `DATABASE_URL` — never hardcode connection strings
- Use `fromService` with `type: keyvalue` and `property: connectionString` for `REDIS_URL`
- Define env vars directly on each service (do not use `envVarGroups`)
- Mark secrets with `sync: false` (user fills these in the Dashboard during Blueprint apply)
- Map region from Heroku using the [service mapping](references/service-mapping.md)
- Only include service/database blocks that the Heroku app actually uses

#### 3A-ii. Validate the Blueprint

This step is mandatory. First, check if the Render CLI is installed:

```bash
render --version
```

If not installed, offer to install it:
- macOS: `brew install render`
- Linux/macOS: `curl -fsSL https://raw.githubusercontent.com/render-oss/cli/main/bin/install.sh | sh`

Once the CLI is available, run the validation command and show the output to the user:

```bash
render blueprints validate render.yaml
```

If validation fails, fix the errors in the YAML and re-validate. Repeat until validation passes. **Do not proceed to the next step until the Blueprint validates successfully.**

#### 3A-iii. Provide the deploy URL

After validation passes:

1. Instruct user to commit and push: `git add render.yaml && git commit -m "Add Render migration Blueprint" && git push`
2. Get the repo URL by running `git remote get-url origin`. If the URL is SSH format (e.g., `git@github.com:user/repo.git`), convert it to HTTPS (`https://github.com/user/repo`). Then construct the deeplink: `https://dashboard.render.com/blueprint/new?repo=<HTTPS_REPO_URL>`
3. Present the **actual working deeplink** to the user — never show a placeholder URL. Guide user to open it, fill in `sync: false` secrets, and click **Apply**

**Do not skip the deploy URL.** The user needs this link to apply the Blueprint on Render.

### Step 3B: MCP Direct Creation (Single-Service)

Before creating resources via MCP, verify the active workspace:

```
get_selected_workspace()
```

If the workspace is wrong, list available workspaces with `list_workspaces()` and ask the user to select the correct one. Resources will be created in whichever workspace is active.

For single-service migrations without databases, create via MCP tools:

1. **Web service** — `create_web_service` with:
   - `runtime`: from the [buildpack mapping](references/buildpack-mapping.md)
   - `buildCommand`: from the [buildpack mapping](references/buildpack-mapping.md)
   - `startCommand`: from Procfile `web:` entry
   - `repo`: user-provided GitHub/GitLab URL
   - `region`: mapped from Heroku region
   - `plan`: mapped from Heroku dyno size using the [service mapping](references/service-mapping.md) (fallback: `starter`)
2. **Static site** — `create_static_site` if detected (instead of web service)

Present the creation result (service URL, ID) when complete.

### Step 4: Migrate Environment Variables

#### Gather config vars

Use the first available source:
1. **Heroku MCP** (preferred) — config vars from `get_app_info` results (Step 1b)
2. **User-provided** — ask the user to paste output of `heroku config -a <app> --shell`
3. **`app.json`** — var names and descriptions (no values, but useful for `sync: false` entries)

#### Filter and categorize

Remove auto-generated and Heroku-specific vars (see the full filter list in the [service mapping](references/service-mapping.md)):
- `DATABASE_URL`, `REDIS_URL`, `REDIS_TLS_URL` (Render generates these)
- `HEROKU_*` vars (e.g., `HEROKU_APP_NAME`, `HEROKU_SLUG_COMMIT`)
- Add-on connection strings (`PAPERTRAIL_*`, `SENDGRID_*`, etc.)

Present filtered list to user — **do not write without confirmation**.

#### Apply vars

**Blueprint path (Step 3A):** Env vars are already embedded in the `render.yaml` on each service (non-secret values inline, secrets marked `sync: false` for the user to fill in during Blueprint apply). No separate MCP call is needed — skip to Step 5.

**MCP path (Step 3B):** Call Render `update_environment_variables` with confirmed vars (supports bulk set, merges by default).

### Step 5: Data Migration

Neither MCP server supports `pg_dump`/`pg_restore` directly. This step generates commands for the user to run. Complete each sub-step in order.

#### 5a. Pre-migration checks

Before generating any migration commands, verify readiness:

1. **Render Postgres is provisioned** — call `get_postgres` via MCP (or confirm in Dashboard) and capture the external connection string
2. **Render Key Value is provisioned** (if Redis data needs migrating) — confirm in Dashboard
3. **Check source database size** — use Heroku MCP `pg_info` (look for `Data Size`), or ask the user to run `heroku pg:info -a <app>` and paste the output
4. **Compare disk sizes** — warn if Heroku `Data Size` exceeds the `diskSizeGB` configured on the Render side. If it does, the user needs to increase `diskSizeGB` before restoring.
5. **Confirm local tools** — check that the user has `pg_dump` and `pg_restore` installed locally:

   ```bash
   pg_dump --version
   pg_restore --version
   ```

   If not installed, suggest installing PostgreSQL client tools (e.g., `brew install libpq` on macOS, `apt install postgresql-client` on Linux).

6. **Redis tools** (if migrating Redis data) — check for `redis-cli`:

   ```bash
   redis-cli --version
   ```

#### 5b. Postgres migration

Generate commands with actual connection strings substituted. Present the full sequence to the user.

**1. Put Heroku in maintenance mode** to stop writes during the migration:

Use `maintenance_on` via Heroku MCP if available, or tell the user to run:

```bash
heroku maintenance:on -a <app>
```

**2. Dump and restore** — choose the approach based on database size:

**Standard approach** (databases under 10 GB):

```bash
# Dump from Heroku
pg_dump -Fc --no-acl --no-owner -d <HEROKU_DB_URL> > heroku_dump.sql
# Restore to Render
pg_restore --clean --no-acl --no-owner -d <RENDER_EXTERNAL_DB_URL> heroku_dump.sql
```

**Pipe approach** (databases 10-50 GB — avoids local disk usage):

```bash
pg_dump -Fc --no-acl --no-owner -d <HEROKU_DB_URL> | pg_restore --clean --no-acl --no-owner -d <RENDER_EXTERNAL_DB_URL>
```

**Very large databases** (over 50 GB): recommend the user [contact Render support](https://render.com/contact) for assisted migration. Do not generate commands — the process requires coordination.

**Connection strings:**
- **Source** — use the first available: Heroku MCP `pg_info` (if available), or ask the user to run `heroku pg:credentials:url -a <app>` and paste the result
- **Destination** — call Render `get_postgres` for the external connection URL

Remind the user to schedule a maintenance window. The app will be unavailable on Heroku from maintenance mode until DNS cutover to Render.

#### 5c. Key Value / Redis migration

Most Heroku Redis instances are used as ephemeral caches and do not need data migration. Ask the user before proceeding:

- **Ephemeral cache** (most common) — skip migration. The app will repopulate the cache after deployment on Render. No action needed.
- **Persistent data** — if the user confirms Redis holds persistent data (e.g., session store, queues, application state), generate migration commands:

  ```bash
  # Dump from Heroku Redis
  redis-cli -u <HEROKU_REDIS_URL> --rdb heroku_dump.rdb
  # Restore to Render Key Value (requires redis-cli 5.0+)
  redis-cli -u <RENDER_REDIS_URL> --pipe < heroku_dump.rdb
  ```

  Note: RDB dump/restore may not be supported on all Heroku Redis plans. If it fails, the alternative is per-key `DUMP`/`RESTORE` or having the application re-seed the data.

#### 5d. Data validation

After the user confirms the restore completed, validate data before moving to Step 6:

**1. Check schema exists on Render:**

```
query_render_postgres(
  postgresId: "<postgres-id>",
  sql: "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name"
)
```

**2. Compare row counts on key tables:**

```
query_render_postgres(
  postgresId: "<postgres-id>",
  sql: "SELECT 'users' AS tbl, count(*) FROM users UNION ALL SELECT 'orders', count(*) FROM orders"
)
```

Adjust the table names to match the app. Pick 2-3 key tables that represent the core data.

**3. Compare against Heroku source** (if Heroku MCP is available):

```
pg_psql(app: "<app>", command: "SELECT 'users' AS tbl, count(*) FROM users UNION ALL SELECT 'orders', count(*) FROM orders")
```

**4. Present a side-by-side summary:**

```
DATA VALIDATION
─────────────────────────────
Table     | Heroku  | Render
users     | 12,450  | 12,450  ✅
orders    | 84,321  | 84,321  ✅
products  | 1,203   | 1,203   ✅
─────────────────────────────
```

If counts don't match, warn the user and suggest re-running the restore. Do not proceed to Step 6 until validation passes.

### Step 6: Verify Migration

After user confirms database migration is complete, run through each check in order. Stop at the first failure, fix it, and redeploy before continuing.

#### 1. Confirm deploy status

```
list_deploys(serviceId: "<service-id>", limit: 1)
```

Expect `status: "live"`. If status is `failed`, inspect build and runtime logs immediately.

#### 2. Verify service health

Hit the health endpoint (or `/`) and confirm a 200 response. If there is no health endpoint, verify the app binds to `0.0.0.0:$PORT` (not `localhost`).

#### 3. Scan error logs

```
list_logs(resource: ["<service-id>"], level: ["error"], limit: 50)
```

Look for clear failure signatures: missing env vars, connection refused, module not found, port binding errors.

#### 4. Verify env vars and port binding

Confirm all required env vars are set — especially secrets marked `sync: false` during Blueprint apply. Ensure the app binds to `0.0.0.0:$PORT`.

#### 5. Check resource metrics

```
get_metrics(
  resourceId: "<service-id>",
  metricTypes: ["http_request_count", "cpu_usage", "memory_usage"]
)
```

Verify CPU and memory are within expected ranges for the selected plan.

#### 6. Confirm database connectivity

```
query_render_postgres(postgresId: "<postgres-id>", sql: "SELECT count(*) FROM <key_table>")
```

Run a read-only query on a key table to confirm data was restored correctly. Compare row counts against the Heroku source if possible.

Present a health summary after all checks pass.

### Step 7: DNS Cutover (Manual)

Instruct user to:
1. Add CNAME pointing domain to `[service-name].onrender.com`
2. Remove/update old Heroku DNS entries
3. Wait for propagation

## Rollback Plan

If the migration fails at any point:

- **Services created but not working**: Services can be deleted from the Render dashboard (MCP server intentionally does not support deletion). Heroku app is untouched until maintenance mode is enabled.
- **Env vars wrong**: Call `update_environment_variables` with `replace: true` to overwrite, or fix individual vars.
- **Database migration failed**: Render Postgres can be deleted and recreated. Heroku database is read-only during dump (no data loss). If `maintenance_off` is called on Heroku, the original app is fully operational again.
- **DNS already changed**: Revert CNAME to Heroku and disable maintenance mode on Heroku.

Key principle: **Heroku stays fully functional until the user explicitly cuts over DNS.** The migration is additive until that final step.

## Error Handling

- Service creation fails: show error, suggest fixes (invalid plan, bad repo URL)
- Env var migration partially fails: show which succeeded/failed
- Heroku auth errors: instruct `heroku login` or check `HEROKU_API_KEY`
- Render auth errors: check Render API key in MCP config
