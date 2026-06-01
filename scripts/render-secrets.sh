#!/bin/sh
# render-secrets.sh — materialize secrets from a manager into the process
# environment at boot, so they live in the manager (sigil / Vaultwarden) rather
# than a committed .env. Nothing here is ever written to a tracked file.
#
# OPT-IN: a no-op unless SECRET_BACKEND is set. Backends:
#   sigil  -> `sigil read <ref>`     (op-style; ref e.g. op://Telemachus/openai/key)
#   rbw    -> `rbw get <ref>`        (Vaultwarden; ref is the entry name)
#
# Each target var is fetched only if its reference is configured via
# TELEMACHUS_SECRET_<VAR>. Handled vars (all optional):
#   OPENAI_API_KEY  ODYSSEUS_ADMIN_PASSWORD  SEARXNG_SECRET  TELEMACHUS_APP_KEY
#
# Usage:
#   eval "$(SECRET_BACKEND=rbw \
#           TELEMACHUS_SECRET_OPENAI_API_KEY='telemachus/openai' \
#           ./scripts/render-secrets.sh --export)"        # for shells / Docker entrypoint
#   ./scripts/render-secrets.sh --envfile /run/telemachus/secrets.env   # then `set -a; . file`
set -eu

MODE="--export"
ENVFILE=""
case "${1:---export}" in
    --export) MODE="--export" ;;
    --envfile) MODE="--envfile"; ENVFILE="${2:?--envfile needs a path}" ;;
    *) echo "usage: $0 [--export | --envfile PATH]" >&2; exit 2 ;;
esac

backend="${SECRET_BACKEND:-}"
if [ -z "$backend" ]; then
    # No backend configured: truncate the envfile (so a stale one can't linger)
    # and exit cleanly. The app falls back to its normal .env / env behaviour.
    [ "$MODE" = "--envfile" ] && { umask 077; : > "$ENVFILE"; }
    exit 0
fi

fetch() {  # <ref> -> value on stdout
    case "$backend" in
        sigil) sigil read "$1" ;;
        rbw)   rbw get "$1" ;;
        *) echo "render-secrets: unknown SECRET_BACKEND '$backend' (want: sigil|rbw)" >&2; return 1 ;;
    esac
}

if [ "$MODE" = "--envfile" ]; then umask 077; : > "$ENVFILE"; fi

# Single-quote-escape a value for safe `eval` of the --export form.
_sq() { printf "%s" "$1" | sed "s/'/'\\\\''/g"; }

emit() {  # <VAR> <VALUE>
    if [ "$MODE" = "--envfile" ]; then
        printf '%s=%s\n' "$1" "$2" >> "$ENVFILE"
    else
        printf "export %s='%s'\n" "$1" "$(_sq "$2")"
    fi
}

for var in OPENAI_API_KEY ODYSSEUS_ADMIN_PASSWORD SEARXNG_SECRET TELEMACHUS_APP_KEY; do
    eval "ref=\${TELEMACHUS_SECRET_$var:-}"
    [ -n "$ref" ] || continue
    if ! val="$(fetch "$ref")"; then
        echo "render-secrets: failed to fetch $var from $backend ($ref)" >&2
        exit 1
    fi
    [ -n "$val" ] || { echo "render-secrets: empty value for $var ($ref)" >&2; exit 1; }
    emit "$var" "$val"
done
