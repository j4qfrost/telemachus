#!/usr/bin/env bash
# Telemachus — Arch Linux dependency bootstrap.
#
# On Arch (and Manjaro/EndeavourOS/CachyOS …) the system Python is
# externally-managed (PEP 668): `pip install` into it is refused, and the
# convention is to install Python packages from the official repositories with
# pacman instead. This script does exactly that:
#
#   1. pacman -S the system prerequisites + every dependency Arch packages.
#   2. create a venv that can SEE those system packages (--system-site-packages).
#   3. pip-install (into the venv) only the handful of packages Arch does not
#      package, pinned to the versions in requirements.txt.
#
# Trade-off (chosen deliberately): pacman-sourced packages follow Arch's
# versions, NOT the requirements.txt pins. The 5 pip-fallback packages stay
# pinned. If you need a fully-pinned, reproducible install, use the plain
# venv+pip path instead:  python -m venv .venv && .venv/bin/pip install -r requirements.txt
#
# Usage:
#   ./bootstrap-arch.sh                          # interactive (pacman prompts)
#   TELEMACHUS_NONINTERACTIVE=1 ./bootstrap-arch.sh   # pacman --noconfirm
#   TELEMACHUS_USE_AUR=1 ./bootstrap-arch.sh     # try the AUR (yay/paru) for the
#                                                # not-in-repos packages before pip
#
# Re-runnable: pacman --needed skips installed packages; pip skips satisfied
# requirements.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

say()  { printf '\033[1;36m›\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$1" >&2; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

# ── Guard: Arch family only ──────────────────────────────────────────────────
ID=""; ID_LIKE=""
[ -r /etc/os-release ] && . /etc/os-release
case " ${ID} ${ID_LIKE:-} " in
  *" arch "*) : ;;
  *) die "Not an Arch-family system (ID='${ID}' ID_LIKE='${ID_LIKE:-}'). Use ./start-linux.sh (venv+pip) instead." ;;
esac
command -v pacman >/dev/null 2>&1 || die "pacman not found."

# ── System prerequisites: interpreter, pip (for the venv), build tools, tmux ──
SYSTEM_PKGS=(python python-pip base-devel tmux)

# ── App deps available in the official repos — installed system-wide via pacman.
#    These follow Arch's versions, not the requirements.txt pins. ──────────────
PACMAN_PKGS=(
  python-fastapi uvicorn python-multipart python-dotenv python-httpx
  python-pydantic python-pydantic-settings python-sqlalchemy python-pypdf
  python-beautifulsoup4 python-charset-normalizer python-numpy python-pillow
  python-markdown python-icalendar python-dateutil python-caldav
  python-cryptography python-bcrypt python-pyotp python-qrcode
)

# ── Deps Arch does NOT package — pip-installed INTO the venv, kept pinned.
#    Keep these versions in sync with requirements.txt. ───────────────────────
PIP_FALLBACK=(
  "mcp==1.27.2"
  "croniter==6.2.2"
  "fastembed==0.8.0"
  "chromadb-client==1.5.9"
  "youtube-transcript-api==1.2.4"
)
# AUR equivalents, tried first when TELEMACHUS_USE_AUR=1.
AUR_FALLBACK=(
  python-mcp python-croniter python-fastembed python-chromadb-client
  python-youtube-transcript-api
)

PAC_FLAGS=(-S --needed)
[ -n "${TELEMACHUS_NONINTERACTIVE:-}" ] && PAC_FLAGS+=(--noconfirm)

say "Installing system + Python packages via pacman (sudo)…"
sudo pacman "${PAC_FLAGS[@]}" "${SYSTEM_PKGS[@]}" "${PACMAN_PKGS[@]}"

# ── Optional: pull the not-in-repos packages from the AUR instead of pip ──────
AUR_HELPER=""
if [ -n "${TELEMACHUS_USE_AUR:-}" ]; then
  for h in yay paru; do command -v "$h" >/dev/null 2>&1 && { AUR_HELPER="$h"; break; }; done
  if [ -n "$AUR_HELPER" ]; then
    say "Installing not-in-repos packages from the AUR via $AUR_HELPER…"
    "$AUR_HELPER" -S --needed "${AUR_FALLBACK[@]}" || warn "AUR install hit errors; pip will cover the rest."
  else
    warn "TELEMACHUS_USE_AUR set but no yay/paru found — falling back to pip."
  fi
fi

# ── Venv that can see the pacman-installed packages ──────────────────────────
VENV=".venv"
if [ ! -d "$VENV" ]; then
  say "Creating venv ($VENV, --system-site-packages so pacman packages are visible)…"
  python -m venv --system-site-packages "$VENV"
elif ! grep -q 'include-system-site-packages = true' "$VENV/pyvenv.cfg" 2>/dev/null; then
  warn "Existing $VENV does not include system site-packages — pacman deps will be invisible to it."
  warn "Recreate it:  rm -rf $VENV && ./bootstrap-arch.sh"
fi

# ── pip the remaining packages (pinned) into the venv. pip treats the
#    --system-site-packages packages as already-satisfied, so it only adds what
#    is genuinely missing (and any unique transitive deps). ────────────────────
say "pip-installing the packages Arch does not provide (pinned), into $VENV…"
"$VENV/bin/python" -m pip install --quiet --upgrade pip
# Skip ones already satisfied by an AUR install above; pip is idempotent anyway.
"$VENV/bin/python" -m pip install "${PIP_FALLBACK[@]}"

# ── First-run app setup (admin user, data dirs) ──────────────────────────────
say "Running app setup…"
ODYSSEUS_SKIP_RUN_HINT=1 "$VENV/bin/python" setup.py

say "Done. Launch with:  ./start-linux.sh"
say "  (equivalently:  $VENV/bin/python -m uvicorn app:app --host 127.0.0.1 --port \${ODYSSEUS_PORT:-7000})"
