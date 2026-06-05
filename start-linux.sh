#!/usr/bin/env bash
# Telemachus — one-command Linux setup + launch.
#
#   ./start-linux.sh
#
# Idempotent: creates the venv and installs deps on first run, then starts the
# local server and opens the UI in an app-style window. Mirrors start-macos.sh.
# Override the port with ODYSSEUS_PORT (default 7000).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"
PORT="${ODYSSEUS_PORT:-7000}"
URL="http://127.0.0.1:${PORT}"

say() { printf '\033[1;36m›\033[0m %s\n' "$1"; }
die() { printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

# ── Open the UI in a chrome-less app window, else the default browser. ──
open_ui() {
  local b
  for b in chromium chromium-browser google-chrome google-chrome-stable brave-browser microsoft-edge; do
    if command -v "$b" >/dev/null 2>&1; then
      "$b" --app="$URL" --new-window >/dev/null 2>&1 &
      return 0
    fi
  done
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL" >/dev/null 2>&1 &
  else
    say "Open $URL in your browser."
  fi
}

# ── Already running? Just open the UI. ──
if curl -s -o /dev/null --max-time 2 "$URL"; then
  say "Telemachus is already running at $URL"
  open_ui
  exit 0
fi

# ── Find Python 3.11+ ──
PY=""
for cand in python3.13 python3.12 python3.11 python3; do
  if command -v "$cand" >/dev/null 2>&1; then
    if "$cand" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] >= (3,11) else 1)'; then
      PY="$cand"; break
    fi
  fi
done
[ -n "$PY" ] || die "Python 3.11+ not found. Install it (e.g. 'sudo pacman -S python' or 'sudo apt install python3') and re-run."

# ── Venv: reuse an existing one, else create .venv ──
VENV=""
for v in .venv venv; do
  if [ -x "$REPO_DIR/$v/bin/uvicorn" ]; then VENV="$v"; break; fi
done
if [ -z "$VENV" ]; then
  VENV=".venv"
  say "Creating venv ($VENV) and installing dependencies (first run only)…"
  "$PY" -m venv "$VENV"
  "$REPO_DIR/$VENV/bin/pip" install --quiet --upgrade pip
  "$REPO_DIR/$VENV/bin/pip" install -r requirements.txt
  ODYSSEUS_SKIP_RUN_HINT=1 "$REPO_DIR/$VENV/bin/python" setup.py
fi
UVICORN="$REPO_DIR/$VENV/bin/uvicorn"

# ── Launch the server; stop it when this script exits ──
mkdir -p logs
say "Starting Telemachus on $URL …"
"$UVICORN" app:app --host 127.0.0.1 --port "$PORT" >>logs/telemachus-app.log 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT INT TERM

# First run downloads an embedding model — allow ~2 min.
for _ in $(seq 1 120); do
  if curl -s -o /dev/null --max-time 2 "$URL"; then
    say "Ready. Opening the UI…"
    open_ui
    break
  fi
  kill -0 "$SERVER_PID" 2>/dev/null || die "Server exited during startup — see logs/telemachus-app.log"
  sleep 1
done

wait "$SERVER_PID"
