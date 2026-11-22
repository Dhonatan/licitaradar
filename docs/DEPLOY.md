# Deploying LicitaRadar

LicitaRadar is one Rails app plus one PostgreSQL database. Background work (the PNCP sync
every 6 hours and the 07:00 daily digest) runs on **Solid Queue**, whose tables live in the
same database — no Redis, no separate cron.

The production image is built from the [`Dockerfile`](../Dockerfile) and CI builds it
and boots it against PostgreSQL on every push (job "Docker image"), so `main` always has a
working image.

## What you need

| Piece | Notes |
| --- | --- |
| PostgreSQL **14+** | Full-text search with the `portuguese` configuration (built in). One database. |
| A container host | Render, Fly.io, a VPS with Kamal, or anything that runs a Docker image. |
| SMTP provider | Password resets, daily digests and admin alerts (Postmark, SES, Brevo, Mailgun...). |
| Outbound HTTPS to `pncp.gov.br` | The sync calls the public PNCP API (no key needed). |

## Environment variables

| Variable | Required | Purpose |
| --- | --- | --- |
| `DATABASE_URL` | yes | `postgres://user:password@host:5432/licitaradar_production` |
| `SECRET_KEY_BASE` | yes | Signs sessions, unsubscribe and password-reset tokens. `openssl rand -hex 64`. Never change it after launch (all links and sessions would break). |
| `APP_HOST` | yes | Public host name used in e-mail links (`licitaradar.com.br`). |
| `MAIL_FROM` | yes | Sender, e.g. `LicitaRadar <alertas@licitaradar.com.br>`. |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | yes for e-mail | Without `SMTP_ADDRESS` no e-mail is delivered. |
| `SOLID_QUEUE_IN_PUMA` | see below | `1` runs the jobs and the schedule inside the web process. |
| `JOB_CONCURRENCY` | no | Solid Queue worker processes (default 1). |
| `ADMIN_EMAIL` | recommended | Receives an alert when the PNCP sync keeps failing (comma-separated list). |
| `STATUS_USERNAME`, `STATUS_PASSWORD` | recommended | Enable the admin page `/status` (basic auth). Unset = page disabled. |
| `RAILS_MAX_THREADS` | no | Puma threads and DB pool size (default 3 threads, pool 5). |
| `PORT` | no | HTTP port (default 3000). |
| `FORCE_SSL`, `ASSUME_SSL` | no | Default `true`: the app expects to sit behind an HTTPS proxy. Set both to `false` only for local tests over plain HTTP. |
| `RAILS_LOG_LEVEL` | no | Default `info`. Logs go to stdout. |
| `SKIP_DB_PREPARE` | no | `1` stops the entrypoint from running `db:prepare` (when migrations run as a release step). |
| `SEED_DEMO_DATA` | no | `1` lets `bin/rails db:seed` load the 30 fictional tenders in production (demo instances only). |

`.env.example` lists them with placeholder values. Keep real values in the host's secret
store, never in the repository.

## How the processes run

The image has one entrypoint ([`bin/docker-entrypoint`](../bin/docker-entrypoint)). When the
command is the web server it first runs `bin/rails db:prepare`: it creates the database if
needed, loads `db/schema.rb` into an empty database or runs pending migrations.

Pick one of two layouts:

1. **Single service (simplest, enough for the first thousands of users).** Run the web
   server with `SOLID_QUEUE_IN_PUMA=1`. Puma starts Solid Queue's supervisor, worker,
   dispatcher and scheduler next to the web server.
2. **Web + worker.** Run the web server without `SOLID_QUEUE_IN_PUMA`, and a second service
   from the same image with the command `./bin/jobs`. Scale them independently; a long sync
   never slows down page loads.

Solid Queue de-duplicates recurring tasks in the database, so running more than one
scheduler does not send the digest twice. The schedule (`config/recurring.yml`, Brasília
time): sync at 00:30, 06:30, 12:30 and 18:30; digest at 07:00.

### Shared state to keep in mind

- **Rate limits** (login, sign-up, password reset, API) count in `Rails.cache`. Production
  uses the default file store, which is per container. With one web container that is
  fine; with several, configure a shared store (Solid Cache or Redis) or the limits apply
  per container.
- The containers keep nothing on disk: all state is in PostgreSQL.

## After the first deploy

1. `GET /up` returns 200 (also the health check path for the platform).
2. Fill the database right away instead of waiting for the next scheduled sync:
   `bin/rails pncp:sync` in a one-off container/console (takes a few minutes; the PNCP is
   slow). Then open `/tenders`.
3. Open `/status` (with `STATUS_USERNAME`/`STATUS_PASSWORD`): every modality should be
   "ok" and "processos ativos" greater than 0.
4. Create an account, request a password reset and check that the e-mail arrives
   (SMTP and `APP_HOST`). Save a search; the digest goes out the next morning at 07:00.
5. Point an uptime monitor at `/status.json` (with basic auth): it answers 503 when the
   sync has been failing or is more than 12 hours old.

## Render

1. Create a **PostgreSQL** instance (Render Postgres) in the region closest to your users
   that Render offers, and copy its *Internal Database URL*. Put the web service in the
   same region.
2. Create a **Web Service** from this repository, runtime **Docker** (Render uses the
   `Dockerfile`). Health check path: `/up`.
3. Environment: `DATABASE_URL`, `SECRET_KEY_BASE`, `APP_HOST` (your Render or custom
   domain), `MAIL_FROM`, `SMTP_*`, `ADMIN_EMAIL`, `STATUS_USERNAME`, `STATUS_PASSWORD` and
   `SOLID_QUEUE_IN_PUMA=1`.
4. Use an instance type that stays on (free instances sleep, and a sleeping service does not
   run the schedule).
5. For layout 2, add a **Background Worker** from the same repository with the command
   `./bin/jobs` and the same environment (without `SOLID_QUEUE_IN_PUMA`).
6. First sync: Render Shell → `bin/rails pncp:sync`.

## Fly.io

```bash
fly launch --no-deploy                 # detects the Dockerfile; choose region gru (São Paulo)
fly postgres create                    # or use any managed PostgreSQL
fly postgres attach <db-app-name>      # sets DATABASE_URL
fly secrets set SECRET_KEY_BASE=$(openssl rand -hex 64) APP_HOST=licitaradar.fly.dev \
  MAIL_FROM="LicitaRadar <alertas@seu-dominio>" SMTP_ADDRESS=... SMTP_USERNAME=... SMTP_PASSWORD=... \
  ADMIN_EMAIL=voce@seu-dominio STATUS_USERNAME=admin STATUS_PASSWORD=$(openssl rand -hex 24)
```

In `fly.toml`, keep at least one machine running (the schedule needs it) and add the
health check:

```toml
[env]
  SOLID_QUEUE_IN_PUMA = "1"

[http_service]
  internal_port = 3000
  force_https = true
  auto_stop_machines = "off"
  min_machines_running = 1

[[http_service.checks]]
  path = "/up"
  interval = "30s"
  timeout = "5s"
```

For layout 2 use Fly process groups instead of `SOLID_QUEUE_IN_PUMA`:

```toml
[processes]
  web = "./bin/rails server"
  worker = "./bin/jobs"
```

Then `fly deploy`, and `fly ssh console -C "/rails/bin/rails pncp:sync"` for the first sync.

## Kamal (any VPS)

Kamal is not in the `Gemfile` (install it with `gem install kamal`). A minimal
`config/deploy.yml`:

```yaml
service: licitaradar
image: your-registry-user/licitaradar

servers:
  web:
    - 203.0.113.10
  job:
    hosts:
      - 203.0.113.10
    cmd: ./bin/jobs

proxy:
  ssl: true
  host: licitaradar.com.br
  app_port: 3000
  healthcheck:
    path: /up

registry:
  username: your-registry-user
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    APP_HOST: licitaradar.com.br
    MAIL_FROM: "LicitaRadar <alertas@licitaradar.com.br>"
  secret:
    - DATABASE_URL
    - SECRET_KEY_BASE
    - SMTP_ADDRESS
    - SMTP_USERNAME
    - SMTP_PASSWORD
    - ADMIN_EMAIL
    - STATUS_USERNAME
    - STATUS_PASSWORD
```

Secrets go in `.kamal/secrets` (never committed). Run PostgreSQL as a managed service or as
a Kamal accessory with a persistent volume and backups. `kamal setup`, then
`kamal app exec "bin/rails pncp:sync"`.

## Any other Docker host

```bash
docker build -t licitaradar .
docker run -d --name licitaradar -p 3000:3000 --restart unless-stopped \
  -e DATABASE_URL=... -e SECRET_KEY_BASE=... -e APP_HOST=... -e MAIL_FROM=... \
  -e SMTP_ADDRESS=... -e SMTP_USERNAME=... -e SMTP_PASSWORD=... \
  -e SOLID_QUEUE_IN_PUMA=1 licitaradar
```

Put an HTTPS reverse proxy (Caddy, nginx, Traefik) in front of it, or set
`FORCE_SSL=false ASSUME_SSL=false` only if TLS is terminated somewhere that does not send
`X-Forwarded-Proto`.

## Operations

- **Backups:** daily `pg_dump` (or the provider's automatic backups). The database holds
  accounts, saved searches and what was already e-mailed; tenders can be re-synced.
- **Upgrades:** deploy the new image; the entrypoint runs pending migrations before the
  server starts. With several web containers, run `bin/rails db:migrate` as a release step
  and set `SKIP_DB_PREPARE=1`.
- **Sync problems:** `/status` shows each modality's latest run and error. The job retries
  failed modalities after 15 and 60 minutes and e-mails `ADMIN_EMAIL` when the third
  attempt fails. A manual run: `bin/rails pncp:sync` (or `MODALITIES=6 bin/rails pncp:sync`).
- **Failed jobs:** counted on `/status`; inspect them in a console with
  `SolidQueue::FailedExecution.last(10)` and retry with `SolidQueue::FailedExecution.find(id).retry`.
- **Logs:** stdout, tagged with the request id.
- **Data growth:** closed tenders are kept (see [`docs/PERFORMANCE.md`](PERFORMANCE.md));
  watch the database size.
