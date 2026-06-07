FROM python:3.12-slim@sha256:090ba77e2958f6af52a5341f788b50b032dd4ca28377d2893dcf1ecbdfdfe203

# System deps. tmux is required by Cookbook for background downloads/serves.
# openssh-client is required for Cookbook remote server tests, setup, probes,
# downloads, and serves from Docker installs.
# git/cmake are required when Cookbook builds llama.cpp on first llama.cpp
# launch inside Docker.
# gosu lets the entrypoint drop privileges cleanly so signals still reach
# uvicorn directly (no extra shell layer like `su`/`sudo` would add).
#
# nodejs/npm are intentionally NOT installed: their only purpose was npx for the
# optional Browser MCP server, which builtin_mcp.py now skips cleanly when npx is
# absent. Dropping Node shrinks this privileged image's attack surface.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    curl \
    git \
    tmux \
    openssh-client \
    gosu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python deps first (layer cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app code
COPY . .

# Create data directory (mount a volume here for persistence)
RUN mkdir -p data logs

# Entrypoint that drops to PUID/PGID (default 1000:1000) and repairs
# ownership on the bind-mounted /app/data and /app/logs. Without this,
# the container runs as root and writes root-owned files into host
# bind mounts — any later non-root run (or a host user trying to
# update them) silently fails on EPERM, breaking skill extraction,
# prefs persistence, mail attachments, etc.
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 7000

# Container-level liveness on the existing /api/health route. curl is already
# installed above. Uses the in-container port (APP_PORT, default 7000) on
# loopback so it works regardless of the published host bind. start-period
# covers first-boot model/index init before the app answers.
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${APP_PORT:-7000}/api/health" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Bind host/port are env-driven. BIND_HOST defaults to 0.0.0.0 because inside a
# container the process must listen on the container interface for the published
# port to work — tailnet exposure is controlled at the PUBLISH layer instead
# (docker-compose `APP_BIND`, default 127.0.0.1). `exec` keeps uvicorn as PID 1's
# child so SIGTERM from `docker stop` reaches it directly.
CMD ["sh", "-c", "exec uvicorn app:app --host \"${BIND_HOST:-0.0.0.0}\" --port \"${APP_PORT:-7000}\""]
