# Build-time Stats

Privacy-safe, aggregated build-time stats for `content/stats.md`.

## What is generated

- `static/data/atuin.json` — aggregated shell usage from Atuin `history.db` (base command only, no args/cwd/host).
- `static/data/github.json` — GitHub contributions via GraphQL (public data only).

If secrets/DB are missing, sample JSON is copied so `hugo --minify` never fails.

## Privacy

- Only first token of `command` (base command) is counted.
- Raw commands, cwd, host, secrets are **never** emitted.
- Denylist: `password|passwd|secret|token|key|aws|gpg|vault|gh_token|github_token` — any command matching is dropped.
- Per-day counts use `timestamp` (ns) → `date(timestamp/1000000000,'unixepoch')` aggregated per day, last 60 days.
- GitHub data is public contributions only.

## Local Hugo build (no secrets)

```bash
bash scripts/export-atuin-stats.sh   # falls back to static/data/atuin.sample.json
node scripts/fetch-github-stats.mjs  # falls back to static/data/github.sample.json
hugo --minify
```

## Docker build without secrets (fallback samples)

```bash
docker build -t vandijke.xyz:test .
```

## Docker build with secrets (BuildKit)

Requires Docker BuildKit (`DOCKER_BUILDKIT=1`).

```bash
# Recommended: pre-aggregate locally (few KB, avoids 500KiB secret limit on full history.db)
bash scripts/export-atuin-stats.sh
DOCKER_BUILDKIT=1 docker build \
  --secret id=atuin_json,src=static/data/atuin.json \
  --secret id=gh_token,env=GITHUB_TOKEN \
  -t vandijke.xyz:secret .

# Alternative (small DBs only, fails if >500KiB):
DOCKER_BUILDKIT=1 docker build \
  --secret id=atuin_db,src=$HOME/.local/share/atuin/history.db \
  --secret id=gh_token,env=GITHUB_TOKEN \
  -t vandijke.xyz:secret .
```

- `atuin_json` is mounted at `/run/secrets/atuin_json` (priority 0, recommended).

- `atuin_db` is mounted at `/run/secrets/atuin_db` (priority 1).
- `gh_token` is mounted at `/run/secrets/gh_token` (also checks `GH_TOKEN` / `GITHUB_TOKEN` env and `GH_USER`).

## CI

`.github/workflows/ci.yaml` runs both scripts before `hugo` and passes `--secret id=gh_token,env=GITHUB_TOKEN` to `docker build`.
