#!/usr/bin/env node
import { readFileSync, existsSync, copyFileSync, mkdirSync, writeFileSync } from "fs";
import { execSync } from "child_process";
import path from "path";
import https from "https";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const outFile = path.join(repoRoot, "static/data/github.json");
const sampleFile = path.join(repoRoot, "static/data/github.sample.json");

mkdirSync(path.dirname(outFile), { recursive: true });

function readSecretFile(p) {
  try {
    if (existsSync(p)) return readFileSync(p, "utf8").trim();
  } catch {}
  return null;
}

let token = readSecretFile("/run/secrets/gh_token");
if (!token) token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN || null;
if (token) token = token.trim();
const ghUser = (process.env.GH_USER || "martynvdijke").trim();

function fallback(reason) {
  console.error(`[fetch-github-stats] Fallback to sample: ${reason}`);
  try {
    if (existsSync(sampleFile)) {
      copyFileSync(sampleFile, outFile);
      console.error(`[fetch-github-stats] Copied sample to ${outFile}`);
    } else {
      const minimal = {
        generated_at: new Date().toISOString(),
        user: ghUser,
        totalCommitContributions: 0,
        totalPullRequestContributions: 0,
        weeks: [],
        pullRequests: [],
        privacy_notes: "Sample fallback — no token or fetch failed."
      };
      writeFileSync(outFile, JSON.stringify(minimal, null, 2));
    }
  } catch (e) {
    console.error(`fallback copy failed: ${e.message}`);
    process.exit(0);
  }
  process.exit(0);
}

if (!token) {
  fallback("no token found (/run/secrets/gh_token, GH_TOKEN, GITHUB_TOKEN)");
}

// Build date range: last 365 days
const now = new Date();
const from = new Date(now);
from.setDate(from.getDate() - 365);
const fromISO = from.toISOString();

const query = `
query($login: String!, $from: DateTime!) {
  user(login: $login) {
    contributionsCollection(from: $from) {
      contributionCalendar {
        totalContributions
        weeks {
          firstDay
          contributionDays {
            date
            contributionCount
            color
          }
        }
      }
      contributionCalendar2: contributionCalendar {
        colors
      }
      totalCommitContributions
      totalPullRequestContributions
    }
    pullRequests(first: 10, orderBy: {field: CREATED_AT, direction: DESC}) {
      nodes {
        title
        url
        state
        createdAt
      }
    }
  }
}
`;

// Actually GitHub's contributionCalendar weeks have week { contributionDays: [{date, contributionCount, color}] } and firstDay.
// We'll query correctly; fallback shape handles variations.

const simpleQuery = `
query($login: String!) {
  user(login: $login) {
    contributionsCollection {
      contributionCalendar {
        totalContributions
        weeks {
          firstDay
          contributionDays {
            date
            contributionCount
            color
          }
        }
      }
      totalCommitContributions
      totalPullRequestContributions
    }
    pullRequests(first: 10, orderBy: {field: CREATED_AT, direction: DESC}) {
      nodes {
        title
        url
        state
        createdAt
      }
    }
  }
}
`;

// Use simpleQuery without from to avoid DateTime handling issues, but we still send from var if needed.
// We'll use simpleQuery for max compatibility.

const payload = JSON.stringify({
  query: simpleQuery,
  variables: { login: ghUser }
});

const req = https.request(
  {
    hostname: "api.github.com",
    path: "/graphql",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(payload),
      Authorization: `Bearer ${token}`,
      "User-Agent": "vandijke.xyz-build-stats"
    },
    timeout: 15000
  },
  (res) => {
    let data = "";
    res.on("data", (c) => (data += c));
    res.on("end", () => {
      if (res.statusCode < 200 || res.statusCode >= 300) {
        console.error(`GitHub API ${res.statusCode}: ${data.slice(0, 500)}`);
        fallback(`GitHub API status ${res.statusCode}`);
        return;
      }
      let json;
      try {
        json = JSON.parse(data);
      } catch (e) {
        fallback(`JSON parse failed: ${e.message}`);
        return;
      }
      if (json.errors) {
        console.error(`GraphQL errors: ${JSON.stringify(json.errors).slice(0, 1000)}`);
        fallback("GraphQL errors");
        return;
      }
      const user = json.data?.user;
      if (!user) {
        fallback("No user data returned");
        return;
      }
      const cc = user.contributionsCollection;
      // Normalize weeks to flat array {date,count,color} per week start
      const weeks = [];
      const rawWeeks = cc?.contributionCalendar?.weeks || [];
      for (const w of rawWeeks) {
        // w.firstDay and contributionDays
        let total = 0;
        let color = w.contributionDays?.[0]?.color || "#ebedf0";
        for (const d of w.contributionDays || []) {
          total += d.contributionCount || 0;
          color = d.color || color;
        }
        // Use firstDay as week identifier, count = total contributions that week
        weeks.push({ date: w.firstDay, count: total, color });
      }

      const out = {
        generated_at: new Date().toISOString(),
        user: ghUser,
        totalCommitContributions: cc?.totalCommitContributions ?? 0,
        totalPullRequestContributions: cc?.totalPullRequestContributions ?? 0,
        contributionCalendar: cc?.contributionCalendar ?? null,
        weeks,
        pullRequests: (user.pullRequests?.nodes || []).map((pr) => ({
          title: pr.title,
          url: pr.url,
          state: pr.state,
          createdAt: pr.createdAt
        })),
        privacy_notes: "Aggregated public GitHub contributions only."
      };
      writeFileSync(outFile, JSON.stringify(out, null, 2));
      console.error(`[fetch-github-stats] Wrote ${outFile}`);
    });
  }
);

req.on("error", (e) => fallback(`request error: ${e.message}`));
req.on("timeout", () => {
  req.destroy();
  fallback("request timeout");
});

req.write(payload);
req.end();
