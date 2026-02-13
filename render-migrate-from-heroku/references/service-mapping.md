# Heroku → Render Service Mapping

## How to Use This Reference

Look up the Heroku plan from `ps_list` (dyno size) or `list_addons` (add-on plan slug) and use the corresponding Render plan in the Blueprint or MCP creation call. If the Heroku plan is unknown, use the fallback default.

## Compute (Dynos → Services)

Match by RAM to avoid out-of-memory issues. Worker and cron dynos use the same size mapping as web dynos.

| Heroku dyno | Heroku RAM | Heroku $/mo | Render `plan` value | Render RAM | Render $/mo |
|---|---|---|---|---|---|
| Eco | 512 MB | $5 | `starter` | 512 MB | $7 |
| Basic | 512 MB | $7 | `starter` | 512 MB | $7 |
| Standard-1X | 512 MB | $25 | `starter` | 512 MB | $7 |
| Standard-2X | 1 GB | $50 | `standard` | 2 GB | $25 |
| Performance-M | 2.5 GB | $250 | `pro` | 4 GB | $85 |
| Performance-L | 14 GB | $500 | `pro max` | 16 GB | $225 |
| Performance-L-RAM | 30 GB | $500 | `pro ultra` | 32 GB | $450 |
| Performance-XL | 62 GB | $750 | Custom | Up to 512 GB | Contact Render |
| Performance-2XL | 126 GB | $1500 | Custom | Up to 512 GB | Contact Render |

**Fallback default:** `starter` (when Heroku dyno size is unknown)

**Notes:**
- Worker dynos on Heroku can be any size (Standard-1X, Performance-M, etc.) — use the same mapping based on the dyno size reported by `ps_list`
- Cron jobs use the same mapping — Render cron plans match web/worker plans
- For Performance-XL and Performance-2XL, instruct the user to [contact Render](https://render.com/contact) for custom sizing

## Postgres (Heroku Postgres → Render Postgres)

Heroku has deprecated Mini and Basic plans. Current tiers are Essential, Standard, and Premium.

Render has three Postgres tiers:
- **Basic** — entry-level, for development and low-traffic apps
- **Pro** — balanced CPU-to-RAM ratio (1:4), for production workloads
- **Accelerated** — memory-optimized CPU-to-RAM ratio (1:8), for high-performance and memory-intensive workloads

Map Heroku Essential → Render Basic, Heroku Standard → Render Pro, Heroku Premium → Render Accelerated.

### Essential and legacy plans → Render Basic

| Heroku plan | Heroku disk | Heroku $/mo | Render `plan` value | Render `diskSizeGB` | Render $/mo |
|---|---|---|---|---|---|
| Essential-0 | 1 GB | $5 | `basic-256mb` | 1 | $6 + storage |
| Essential-1 | 10 GB | $9 | `basic-256mb` | 10 | $6 + storage |
| Essential-2 | 32 GB | $20 | `basic-1gb` | 32 | $19 + storage |
| Mini (legacy, EOL) | 1 GB | $5 | `basic-256mb` | 1 | $6 + storage |
| Basic (legacy, EOL) | 10 GB | $9 | `basic-256mb` | 10 | $6 + storage |

### Standard plans → Render Pro

| Heroku plan | Heroku RAM | Heroku disk | Heroku $/mo | Render `plan` value | Render `diskSizeGB` | Render $/mo |
|---|---|---|---|---|---|---|
| Standard-0 | 4 GB | 64 GB | $50 | `pro-4gb` | 65 | $55 + storage |
| Standard-2 | 8 GB | 256 GB | $200 | `pro-8gb` | 256 | $100 + storage |
| Standard-3 | 15 GB | 512 GB | $400 | `pro-16gb` | 512 | $200 + storage |
| Standard-4 | 30 GB | 768 GB | $750 | `pro-32gb` | 770 | $400 + storage |
| Standard-5 | 61 GB | 1 TB | $1,400 | `pro-64gb` | 1024 | $800 + storage |
| Standard-6 | 122 GB | 1.5 TB | $2,000 | `pro-128gb` | 1536 | $1,700 + storage |
| Standard-7 | 244 GB | 2 TB | $3,500 | `pro-256gb` | 2048 | $3,000 + storage |
| Standard-8 | 488 GB | 3 TB | $6,000 | `pro-512gb` | 3072 | $6,200 + storage |
| Standard-9+ | 768 GB+ | 4 TB+ | $9,000+ | Custom | Contact Render | Contact Render |

### Premium plans → Render Accelerated

Heroku Premium is the high-performance tier with HA. Map to Render Accelerated (memory-optimized, 1:8 CPU-to-RAM ratio).

| Heroku plan | Heroku RAM | Heroku disk | Heroku $/mo | Render `plan` value | Render `diskSizeGB` | Render $/mo |
|---|---|---|---|---|---|---|
| Premium-0 | 4 GB | 64 GB | $200 | `accelerated-16gb` | 65 | $160 + storage |
| Premium-2 | 8 GB | 256 GB | $350 | `accelerated-32gb` | 256 | $350 + storage |
| Premium-3 | 15 GB | 512 GB | $750 | `accelerated-64gb` | 512 | $750 + storage |
| Premium-4 | 30 GB | 768 GB | $1,200 | `accelerated-128gb` | 770 | $1,500 + storage |
| Premium-5 | 61 GB | 1 TB | $2,500 | `accelerated-256gb` | 1024 | $2,500 + storage |
| Premium-6 | 122 GB | 1.5 TB | $3,500 | `accelerated-384gb` | 1536 | $4,500 + storage |
| Premium-L-6 | 122 GB | 2 TB | — | `accelerated-384gb` | 2048 | $4,500 + storage |
| Premium-XL-6 | 122 GB | 3 TB | — | `accelerated-384gb` | 3072 | $4,500 + storage |
| Premium-7 | 244 GB | 2 TB | $6,000 | `accelerated-512gb` | 2048 | $6,000 + storage |
| Premium-8+ | 488 GB+ | 3 TB+ | $9,000+ | Custom | Contact Render | Contact Render |

### Disk sizing

On Render, storage is billed separately at **$0.30/GB/month** and configured via the `diskSizeGB` field in the Blueprint.

**Heuristic:** Carry over the Heroku disk size as the `diskSizeGB` value. Since `diskSizeGB` must be 1 or a multiple of 5, round up to the nearest valid value.

**Disclaimer to present to the user:** Render storage is expandable and billed separately. The recommended `diskSizeGB` matches your current Heroku allocation, but you can resize later from the Render Dashboard based on actual usage. Check your current disk usage with `heroku pg:info` (look for `Data Size`) — if your actual data is much smaller than the allocated disk, you may be able to start with a smaller `diskSizeGB` and save on storage costs.

**Fallback default:** `basic-1gb` with no `diskSizeGB` (when Heroku Postgres plan is unknown — Render uses a default disk size)

**Notes:**
- Render Pro and Accelerated both support HA (enable separately in Dashboard or Blueprint)
- For databases beyond these tiers, contact Render support
- The add-on plan slug from `list_addons` looks like `heroku-postgresql:essential-2` or `heroku-postgresql:standard-0` — use the part after the colon to look up the mapping
- Get actual disk usage from `pg_info` (`Data Size` field) to inform the `diskSizeGB` recommendation

## Key Value (Heroku Redis / Key-Value Store → Render Key Value)

Heroku has rebranded Redis as "Key-Value Store" (Valkey-based). Match by memory capacity.

| Heroku plan | Heroku memory | Heroku $/mo | Render `plan` value | Render RAM | Render $/mo |
|---|---|---|---|---|---|
| Mini | 25 MB | $3 | `starter` | 256 MB | $10 |
| Premium-0 | 50 MB | $15 | `starter` | 256 MB | $10 |
| Premium-1 | 100 MB | $30 | `starter` | 256 MB | $10 |
| Premium-2 | 250 MB | $60 | `standard` | 1 GB | $32 |
| Premium-3 | 500 MB | $100 | `standard` | 1 GB | $32 |
| Premium-4 | 1 GB | $200 | `standard` | 1 GB | $32 |
| Premium-5 | 5 GB | $350 | `pro` | 5 GB | $135 |
| Premium-6 | 10 GB | $600 | `pro plus` | 10 GB | $250 |
| Premium-7 | 15 GB | $1000 | `pro max` | 20 GB | $550 |
| Premium-8+ | 25 GB+ | $1500+ | `pro ultra` or Custom | 40 GB+ | $1,100+ |

**Fallback default:** `starter` (when Heroku Redis plan is unknown)

**Notes:**
- The add-on plan slug from `list_addons` looks like `heroku-redis:mini` or `heroku-redis:premium-0` — use the part after the colon to look up the mapping
- Render Key Value requires `ipAllowList` in the Blueprint (use `0.0.0.0/0` for public access)

## Runtime Mapping

| Heroku Buildpack | Render Runtime | `runtime` param |
|---|---|---|
| heroku/nodejs | Node | `node` |
| heroku/python | Python | `python` |
| heroku/go | Go | `go` |
| heroku/ruby | Ruby | `ruby` |
| heroku/java | Docker | `docker` |
| heroku/php | Docker | `docker` |
| heroku/scala | Docker | `docker` |
| Multi-buildpack | Docker | `docker` |

## Region Mapping

| Heroku Region | Render Region | `region` param |
|---|---|---|
| us | Oregon (default) | `oregon` |
| eu | Frankfurt | `frankfurt` |

## Not Directly Mappable (Manual)

These Heroku features require manual alternatives on Render:
- **Heroku Pipelines** → Use Render Preview Environments + manual promotion
- **Review Apps** → Render Pull Request Previews
- **Heroku Add-ons Marketplace** → Find equivalent third-party services
- **Heroku ACM (SSL)** → Render auto-provisions TLS for custom domains
- **Private Spaces** → Contact Render for private networking options

## Environment Variables to Filter

Always exclude these when migrating env vars:

**Render auto-generates:**
- `DATABASE_URL`
- `REDIS_URL`, `REDIS_TLS_URL`

**Heroku-specific (no Render equivalent):**
- `HEROKU_APP_NAME`
- `HEROKU_SLUG_COMMIT`
- `HEROKU_SLUG_DESCRIPTION`
- `HEROKU_DYNO_ID`
- `HEROKU_RELEASE_VERSION`
- `PORT` (Render sets its own)

**Add-on connection strings (replace with new service URLs):**
- `PAPERTRAIL_*`
- `SENDGRID_*`
- `CLOUDAMQP_*`
- `BONSAI_*`
- `FIXIE_*`
- Any other `*_URL` vars pointing to Heroku add-on services
