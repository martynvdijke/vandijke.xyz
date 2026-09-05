#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_FILE="$REPO_ROOT/static/data/atuin.json"
SAMPLE_FILE="$REPO_ROOT/static/data/atuin.sample.json"

mkdir -p "$(dirname "$OUT_FILE")"

# Pre-aggregated JSON secret (few KB, avoids 500KiB BuildKit limit on full history.db)
if [ -f "/run/secrets/atuin_json" ]; then
  echo "Using pre-aggregated secret /run/secrets/atuin_json" >&2
  cp "/run/secrets/atuin_json" "$OUT_FILE"
  exit 0
fi

# Resolve DB path priority: /run/secrets/atuin_db -> $ATUIN_DB_PATH -> $HOME/.local/share/atuin/history.db
DB_PATH=""
if [ -f "/run/secrets/atuin_db" ]; then
  DB_PATH="/run/secrets/atuin_db"
elif [ -n "${ATUIN_DB_PATH:-}" ] && [ -f "$ATUIN_DB_PATH" ]; then
  DB_PATH="$ATUIN_DB_PATH"
elif [ -f "$HOME/.local/share/atuin/history.db" ]; then
  DB_PATH="$HOME/.local/share/atuin/history.db"
fi

fallback_to_sample() {
  echo "No Atuin DB found at expected locations — using sample data." >&2
  if [ -f "$SAMPLE_FILE" ]; then
    cp "$SAMPLE_FILE" "$OUT_FILE"
  else
    echo '{"generated_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","total_commands":0,"unique_commands":0,"top_commands":[],"per_day":[],"privacy_notes":"Aggregated only — no DB available."}' > "$OUT_FILE"
  fi
  exit 0
}

if [ -z "$DB_PATH" ] || [ ! -f "$DB_PATH" ]; then
  fallback_to_sample
fi

echo "Using Atuin DB: $DB_PATH" >&2

# Denylist for sensitive base commands/tokens — never include these in output
DENYLIST="password|passwd|secret|token|key|aws|gpg|vault|gh_token|github_token"

# Try sqlite3 first, fallback to python3
if command -v sqlite3 >/dev/null 2>&1; then
  echo "Querying with sqlite3..." >&2

  # Verify table exists
  if ! sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='history';" | grep -q history; then
    echo "Table 'history' not found — fallback to sample." >&2
    fallback_to_sample
  fi

  # Use read-only via URI or copy? Use sqlite3 directly; query filtering deleted_at IS NULL
  # We produce JSON via python post-processing to handle denylist and aggregation properly.
  # Instead, dump raw commands and aggregate in bash/python for privacy filtering.

  # Dump base commands via sqlite3 with denylist applied later via python
  TMPDIR_CSV=$(mktemp -d)
  trap 'rm -rf "$TMPDIR_CSV"' EXIT

  # Export commands (first token stripped via SQL substr/instr) - we do full command then strip in python for correctness
  # But we can also do base extraction in SQL for counting; we do python aggregation for denylist.
  sqlite3 -separator '	' "$DB_PATH" "SELECT command, timestamp FROM history WHERE deleted_at IS NULL;" > "$TMPDIR_CSV/raw.tsv" || fallback_to_sample

  python3 - "$TMPDIR_CSV/raw.tsv" "$OUT_FILE" "$SAMPLE_FILE" << 'PY'
import sys, json, re
from datetime import datetime, timedelta, timezone
from collections import Counter

raw_path, out_path, sample_path = sys.argv[1], sys.argv[2], sys.argv[3]
denylist_re = re.compile(r'password|passwd|secret|token|key|aws|gpg|vault|gh_token|github_token', re.I)

counter = Counter()
per_day = Counter()
total = 0

try:
    with open(raw_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line=line.rstrip('\n')
            if not line:
                continue
            parts=line.split('\t')
            cmd = parts[0] if parts[0] else ""
            ts_raw = parts[1] if len(parts)>1 else ""
            # Extract base command: first token, strip leading sudo/env wrappers? take first token after trimming
            cmd_stripped = cmd.strip()
            if not cmd_stripped:
                continue
            # Remove leading sudo
            if cmd_stripped.startswith("sudo "):
                cmd_stripped = cmd_stripped[5:].lstrip()
            # base token: split on space, ;, |, &, take first
            m = re.split(r'[\s;|&]+', cmd_stripped, maxsplit=1)
            base = m[0].strip().lower()
            # Remove path prefix
            base = base.split('/')[-1]
            # Denylist
            if denylist_re.search(base) or denylist_re.search(cmd):
                # if raw command contains sensitive keyword, skip entirely
                if denylist_re.search(cmd):
                    continue
                continue
            # Only allow reasonable base names (alphanum, -, _, ., +)
            if not re.match(r'^[a-z0-9._+\-]+$', base):
                continue
            if len(base) > 32:
                continue
            counter[base] += 1
            total += 1
            # per day: timestamp is ns
            try:
                ts_ns = int(ts_raw)
                ts_s = ts_ns // 1_000_000_000
                d = datetime.fromtimestamp(ts_s, tz=timezone.utc).date().isoformat()
                per_day[d] += 1
            except:
                pass
except Exception as e:
    print(f"python aggregation failed: {e}", file=sys.stderr)
    sys.exit(1)

unique = len(counter)
top = [{"command": k, "count": v} for k, v in counter.most_common(20)]

# per_day last 60 days
today = datetime.now(timezone.utc).date()
start = today - timedelta(days=59)
per_day_list = []
for i in range(60):
    d = (start + timedelta(days=i)).isoformat()
    per_day_list.append({"date": d, "count": per_day.get(d, 0)})

out = {
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00","Z"),
    "total_commands": total,
    "unique_commands": unique,
    "top_commands": top,
    "per_day": per_day_list,
    "privacy_notes": "Aggregated only — base commands without args, denylisted sensitive tokens/passwords/secrets, no cwd/host/raw commands."
}
with open(out_path, 'w') as o:
    json.dump(out, o, indent=2)
print(f"Wrote {out_path} total={total} unique={unique}", file=sys.stderr)
PY

else
  # Fallback to python3 sqlite3
  echo "sqlite3 not found, using python3 sqlite3..." >&2
  if ! command -v python3 >/dev/null 2>&1; then
    echo "Neither sqlite3 nor python3 available — fallback to sample." >&2
    fallback_to_sample
  fi
  python3 - "$DB_PATH" "$OUT_FILE" << 'PY'
import sys, json, re, sqlite3
from datetime import datetime, timedelta, timezone
from collections import Counter

db_path, out_path = sys.argv[1], sys.argv[2]
denylist_re = re.compile(r'password|passwd|secret|token|key|aws|gpg|vault|gh_token|github_token', re.I)

try:
    uri = f"file:{db_path}?mode=ro"
    con = sqlite3.connect(uri, uri=True)
    cur = con.cursor()
    # Check table exists
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='history'")
    if not cur.fetchone():
        print("Table history not found", file=sys.stderr)
        sys.exit(2)
    cur.execute("SELECT command, timestamp FROM history WHERE deleted_at IS NULL")
    rows = cur.fetchall()
except SystemExit:
    raise
except Exception as e:
    print(f"sqlite open/query failed: {e}", file=sys.stderr)
    sys.exit(1)

counter = Counter()
per_day = Counter()
total = 0
for cmd, ts_raw in rows:
    if not cmd:
        continue
    cmd_stripped = cmd.strip()
    if not cmd_stripped:
        continue
    if cmd_stripped.startswith("sudo "):
        cmd_stripped = cmd_stripped[5:].lstrip()
    m = re.split(r'[\s;|&]+', cmd_stripped, maxsplit=1)
    base = m[0].strip().lower().split('/')[-1]
    if denylist_re.search(base) or denylist_re.search(cmd):
        if denylist_re.search(cmd):
            continue
        continue
    if not re.match(r'^[a-z0-9._+\-]+$', base):
        continue
    if len(base) > 32:
        continue
    counter[base]+=1
    total+=1
    try:
        ts_s = int(ts_raw)//1_000_000_000
        d = datetime.fromtimestamp(ts_s, tz=timezone.utc).date().isoformat()
        per_day[d]+=1
    except:
        pass

unique=len(counter)
top=[{"command":k,"count":v} for k,v in counter.most_common(20)]
today=datetime.now(timezone.utc).date()
start=today-timedelta(days=59)
per_day_list=[{"date":(start+timedelta(days=i)).isoformat(),"count":per_day.get((start+timedelta(days=i)).isoformat(),0)} for i in range(60)]
out={
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00","Z"),
    "total_commands": total,
    "unique_commands": unique,
    "top_commands": top,
    "per_day": per_day_list,
    "privacy_notes": "Aggregated only — base commands without args, denylisted sensitive tokens/passwords/secrets, no cwd/host/raw commands."
}
with open(out_path,'w') as o:
    json.dump(o, out, indent=2) if False else json.dump(out, o, indent=2)
print(f"Wrote {out_path} total={total} unique={unique}", file=sys.stderr)
PY
  if [ $? -ne 0 ]; then
    echo "Python sqlite fallback failed — using sample." >&2
    fallback_to_sample
  fi
fi

echo "Generated $OUT_FILE" >&2
