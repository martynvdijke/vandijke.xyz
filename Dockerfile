# syntax=docker/dockerfile:1
FROM ghcr.io/gohugoio/hugo:v0.165.0 AS builder
# Fallback: if ghcr image missing, BuildKit will error — alternative is klakegg/hugo:0.165.0-ext or ubuntu+hugo install.
# This stage installs sqlite3 and nodejs for build-time stats, then builds the site.

USER root
RUN if command -v apk >/dev/null 2>&1; then apk add --no-cache sqlite nodejs python3 bash; elif command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y --no-install-recommends sqlite3 nodejs python3 && rm -rf /var/lib/apt/lists/*; else echo "No package manager found" && exit 1; fi

WORKDIR /site
COPY . .

# Build-time stats: use BuildKit secrets if provided, else fallback to samples (build never fails)
RUN --mount=type=secret,id=atuin_db \
    --mount=type=secret,id=atuin_json \
    --mount=type=secret,id=gh_token \
    bash scripts/export-atuin-stats.sh || (echo "export-atuin failed, ensuring sample fallback" && cp -f static/data/atuin.sample.json static/data/atuin.json || true) \
    && node scripts/fetch-github-stats.mjs || (echo "fetch-github failed, ensuring sample fallback" && cp -f static/data/github.sample.json static/data/github.json || true) \
    && hugo --minify

FROM nginx:latest
COPY --from=builder /site/public /usr/share/nginx/html/
