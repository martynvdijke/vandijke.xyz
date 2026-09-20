---
author: "Martyn van Dijke"
title: "Youtube playlist randomizer"
date: 2023-12-21
tags: ["youtube", "go", "htmx"]
description: "Takes a YouTube playlist, shuffles it with the YouTube Data API v3, and saves the result as a new playlist."
showTableOfContents: true
aliases: ["/posts/blog/youtubeplaylist_randomizer/"]
---

Ever had the issue that YouTube's randomize function does not work on Chromecast? No longer — [youtube-playlist-randomizer](https://github.com/martynvdijke/youtube-playlist-randomizer) takes a playlist, shuffles it with the YouTube Data API v3 and saves the result as a brand new playlist.

It runs as a small self-hosted Go web app on port `6270`, with an HTMX-powered UI to browse, filter and randomize your playlists.

## Features

- **Web UI** — browse, filter and randomize playlists from the browser.
- **Quota management** — keeps track of YouTube API quota usage and automatically pauses and resumes jobs when the quota resets.
- **Job persistence** — job state is stored in SQLite and survives server restarts.
- **Docker support** — ready-to-run container image on GHCR.
- **Mock mode** — run it without YouTube API credentials while developing.

## How it works

1. Lists your playlists through the YouTube Data API.
2. Fetches all video IDs of the selected playlist.
3. Shuffles them with the Fisher–Yates algorithm.
4. Creates a new playlist with the shuffled order.
5. Inserts the items one by one, pausing and resuming automatically when the API quota runs out.

## Running it

The quickest way is Docker. Grab an OAuth client ID from a Google Cloud project with the YouTube Data API v3 enabled, download it as `client_secret.json` and run:

```sh
docker run -p 6270:6270 \
  -e OAUTH_CALLBACK_URL=http://localhost:6270/callback \
  -v /path/to/client_secret.json:/config/client_secret.json \
  -v ypr-data:/db \
  ghcr.io/martynvdijke/ypr:latest
```

Or build it from source (needs Go):

```sh
go build -o ypr-server .
./ypr-server -i client_secret.json
```

Then open [http://localhost:6270](http://localhost:6270) and authorize with your Google account.

## Links

- Source code: [github.com/martynvdijke/youtube-playlist-randomizer](https://github.com/martynvdijke/youtube-playlist-randomizer)
- Container image: `ghcr.io/martynvdijke/ypr:latest`
