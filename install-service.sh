#!/bin/bash
# Render telemachus-ui.service from the current environment and install it.
# No hand-editing required (the old flow shipped a unit still containing
# YOURUSER and a wrong :8000 bind). Override any of these via env:
#   SERVICE_USER (default: current user)   INSTALL_DIR (default: this repo)
#   BIND_HOST    (default: 127.0.0.1)       APP_PORT    (default: 7000)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/telemachus-ui.service"
[ -f "$TEMPLATE" ] || { echo "Error: telemachus-ui.service not found in $SCRIPT_DIR" >&2; exit 1; }

SERVICE_USER="${SERVICE_USER:-$(id -un)}"
INSTALL_DIR="${INSTALL_DIR:-$SCRIPT_DIR}"
BIND_HOST="${BIND_HOST:-127.0.0.1}"
APP_PORT="${APP_PORT:-7000}"

# Detect the virtualenv (.venv preferred, then venv) so ExecStart points at a
# real uvicorn rather than a guessed path.
if [ -x "$INSTALL_DIR/.venv/bin/uvicorn" ]; then
  VENV=".venv"
elif [ -x "$INSTALL_DIR/venv/bin/uvicorn" ]; then
  VENV="venv"
else
  echo "Error: no .venv or venv with uvicorn under $INSTALL_DIR — create one first:" >&2
  echo "       python3 -m venv .venv && .venv/bin/pip install -r requirements.txt" >&2
  exit 1
fi

RENDERED="$(mktemp)"
trap 'rm -f "$RENDERED"' EXIT
sed -e "s|__SERVICE_USER__|$SERVICE_USER|g" \
    -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
    -e "s|__VENV__|$VENV|g" \
    -e "s|__BIND_HOST__|$BIND_HOST|g" \
    -e "s|__APP_PORT__|$APP_PORT|g" \
    "$TEMPLATE" > "$RENDERED"

# Footgun guard: never install a unit with unresolved tokens. Ignore comment
# lines so the template's own documentation can't trip it.
if grep -vE '^[[:space:]]*#' "$RENDERED" | grep -qE '__[A-Z_]+__|YOURUSER'; then
  echo "Error: unresolved tokens in the rendered unit:" >&2
  grep -nE '__[A-Z_]+__|YOURUSER' "$RENDERED" | grep -vE ':[[:space:]]*#' >&2
  exit 1
fi

echo "Installing telemachus-ui.service"
echo "  user=$SERVICE_USER  dir=$INSTALL_DIR  venv=$VENV  bind=$BIND_HOST:$APP_PORT"
sudo cp "$RENDERED" /etc/systemd/system/telemachus-ui.service
sudo systemctl daemon-reload
sudo systemctl enable --now telemachus-ui
sudo systemctl status telemachus-ui --no-pager
