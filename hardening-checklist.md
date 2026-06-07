# Hardening checklist — telemachus (Odysseus fork)

Language: Python 3.12 (CI/runtime target; local dev venv is 3.14)
Framework: FastAPI + uvicorn + SQLAlchemy + Pydantic v2
Entrypoint: `app.py`  ·  Deps: `requirements*.txt` (pip-compile, not uv)
Fork of: `pewdiepie-archdaemon/odysseus` — keep changes additive/surgical to avoid painful `upstream` syncs.

Stage-4 production-hardening assessment. This project is a mature, already-hardened fork:
prior PRs landed pinned CI/release images (by digest), Dependabot, a report-only pip-audit
gate, a reproducible Nix devShell, loopback-default binds, security-headers middleware, a
privilege-dropping Docker entrypoint, and typed exception handlers. The remaining gaps were
in the apps-stall zone: behavioral test of error paths, a catch-all 500, container/service
health wiring, and systemd sandboxing.

---

## Priority (highest-leverage first)

1. **DONE — Catch-all 500 handler.** Unhandled exceptions previously fell through to
   Starlette's default 500; with any debug server that leaks a traceback. Untrusted input
   reaching an un-typed code path is exactly the apps-stall risk. Added a sanitized,
   structured catch-all that logs server-side. (`app.py`)
2. **DONE — Container + service health wiring.** `/api/health` existed but nothing used it.
   The Docker `restart: unless-stopped` policy acted only on process exit, not liveness.
   Added a Dockerfile `HEALTHCHECK` and a compose healthcheck for the `telemachus` service.
3. **DONE — systemd sandboxing.** The unit ran with no confinement. Added conservative,
   app-compatible directives (NoNewPrivileges, ProtectSystem=full, ProtectHome=read-only +
   ReadWritePaths, kernel/cgroup protections). (`telemachus-ui.service`)
4. **DONE — Error-path test coverage.** Added behavioral tests pinning the catch-all 500
   contract (no traceback leak) and the health timestamp being timezone-aware.
5. **OPEN (deferred) — pip-audit hard gate + hash-pinned deps.** See Supply chain below.

---

## Tests
- [x] Golden / behavioral tests for hot paths — 26 test files, 329→334 tests, pure-function
      style (auth gates, rate limiter, endpoint resolver, search ranking, secrets injection,
      prompt-injection wrapper, calendar recurrence, etc.). Strong for a fork.
- [~] Property tests — none present; not idiomatic here and out of scope for a surgical pass.
- [x] Edge-case tests for error paths — typed exception handlers were untested; **added**
      `tests/test_error_handlers.py` (catch-all 500 + no-leak + health tz contract).
- [~] Integration tests for top-level entry points — suite deliberately avoids importing
      `app:app` (heavy init / import pollution). Error-path contracts pinned via an isolated
      minimal app + static guards instead. A full TestClient integration lane is OPEN.
- [ ] Coverage measured — **no coverage tooling installed** (no pytest-cov). OPEN, low-risk.

## Static analysis
- [x] Format/lint passes — `ruff check .` clean (gate is conservative: `select = ["F"]`,
      pyflakes-only; large style debt intentionally deferred per `pyproject.toml`).
- [x] `py_compile` passes on all tracked `*.py` (CI step) — clean.
- [ ] Type check — **no mypy/pyright configured.** OPEN. A strict type gate on a 436-file
      fork is a large effort and would fight upstream; deferred.

## Error paths
- [x] No bare `except:` anywhere in app code (grep: 0).
- [~] `except Exception: pass` — 191 occurrences. Most are deliberate best-effort cleanup
      (cache writes, optional features). NOT swept: rewriting them silently would fight
      upstream and risk behavior change. Flagged as a tiered follow-up, not changed.
- [x] Structured error types in the public API — `src/exceptions.py` + typed FastAPI
      handlers (SessionNotFound 404, InvalidFileUpload 400, LLMService 502, WebSearch 502).
- [x] Top-level handles every error class — **added catch-all `@app.exception_handler(Exception)`**
      returning a sanitized structured 500; logs the real exception with the request path.

## Supply chain
- [x] Lockfile committed — `requirements.txt` is pip-compiled & fully version-pinned
      (`# via` provenance), plus `requirements-dev.txt`, `requirements-optional.txt`.
- [x] Vulnerability scan passes — `pip-audit -r requirements.txt`: **No known vulnerabilities
      found** (ran locally this session). CI runs it report-only (`failure: ignore`).
- [ ] **Hash-pinned deps — MISSING.** `requirements.txt` has 0 `--hash=` lines. Version pins
      without hashes don't defend against a registry/index compromise. OPEN (see Findings).
- [x] Dependabot configured — pip + github-actions + docker ecosystems, weekly.
- [x] Dependency count reviewed — Node dropped from runtime (fork delta); deps are purposeful.
- [ ] License audit — delegate to `@license-auditor` (writes `license-audit.md`). A `licenses/`
      dir + `ACKNOWLEDGMENTS.md` already exist; not re-audited here.

## CI (.woodpecker/ci.yml — snowman Forgejo + Woodpecker)
- [x] Runs on every push + pull_request.
- [x] Runs install → `ruff check` → `py_compile` → `pytest -q`.
- [x] pip-audit step (report-only).
- [x] Nix devShell smoke + `nix flake check` (proves reproducible toolchain resolves).
- [~] pip-audit is `failure: ignore` — intentional bootstrap; flip to hard gate once the
      pinned set is clean (it currently is — candidate to flip). OPEN, low-risk.
- [ ] No coverage step (no coverage tooling). OPEN.
- [x] macOS/Windows desktop bundles built via GitHub Actions (release.yml), pinned by digest.

## Deploy
- [x] Reproducible build — Dockerfile base + all compose service images pinned **by sha256
      digest**; Nix devShell tarball-pinned.
- [x] Privilege drop — entrypoint uses gosu to drop to PUID/PGID; `exec` keeps uvicorn as
      PID 1's child so SIGTERM reaches it.
- [x] **Container health — ADDED** Dockerfile `HEALTHCHECK` on `/api/health` (curl already in
      image) + compose `telemachus` service healthcheck.
- [x] **systemd hardening — ADDED** sandbox directives to `telemachus-ui.service`.
- [x] Loopback-default binds everywhere (compose `APP_BIND=127.0.0.1`, systemd `--host`
      loopback, Dockerfile documents the publish-layer exposure model).
- [x] Release process documented — `.woodpecker/release.yml` (tag → kaniko OCI image + Linux
      bundle); secret-injection hook (sigil/Vaultwarden) wired into the systemd unit.
- [ ] Rollback path not explicitly documented (images are tagged, so feasible). OPEN, low.

## Observability
- [x] Structured-ish logging — `logging.basicConfig` + `logging.getLogger(__name__)` across
      ~104 files; the new catch-all logs unhandled exceptions with method+path.
- [x] Log levels respected (info/warning/error used appropriately in `app.py`).
- [x] Health endpoint — `/api/health` (+ `/api/version`, `/api/runtime`); now wired into
      container + service healthchecks.
- [ ] Metrics endpoint (Prometheus/OTLP) — none. OPEN; domain-appropriate but out of scope
      for this surgical pass (would be a feature add).

---

## Changes made this session (branch `feat/hardening`)

| File | Change | Why |
|------|--------|-----|
| `app.py` | Added `@app.exception_handler(Exception)` catch-all → sanitized structured 500, logs real exc + request path | Prevent traceback leak on untrusted-input paths; ensure unhandled errors are observable |
| `app.py` | `/api/health` timestamp: `datetime.utcnow()` → `datetime.now(timezone.utc)` | Remove deprecated naive-UTC call that warns now and breaks on a future Python |
| `Dockerfile` | Added `HEALTHCHECK` curl-ing `/api/health` | Make `restart` policy act on real liveness |
| `docker-compose.yml` | Added `telemachus` service `healthcheck` | Surface app health in `compose ps` / orchestrators |
| `telemachus-ui.service` | Added systemd sandbox directives (NoNewPrivileges, ProtectSystem=full, ProtectHome=read-only + ReadWritePaths, kernel/cgroup/SUID protections) | Reduce blast radius of a compromise |
| `tests/test_error_handlers.py` | New: catch-all 500 behavior + no-leak + health tz contract (5 tests) | Pin the error-path hardening so it can't silently regress |

Local checks run this session (shared-venv `.venv`, Python 3.14):
- `ruff check .` → **All checks passed!**
- `python -m py_compile $(git ls-files '*.py')` → exit 0
- `pytest -q` → **334 passed**, 10 warnings (pre-existing SQLAlchemy/utcnow deprecations in deps)
- `pip-audit -r requirements.txt` → **No known vulnerabilities found**
- `docker-compose.yml` YAML parse → OK

---

## Risk-tiered remaining work

**Tier 1 (do next — supply-chain / signal):**
- Hash-pin `requirements*.txt` (`pip-compile --generate-hashes`) and install with
  `pip install --require-hashes`. Defends against index/registry tampering. Needs a clean
  regenerate so transitive hashes are complete.
- Flip the CI `pip-audit` step from `failure: ignore` to a hard gate (the set is currently
  clean, so the cost is zero today).

**Tier 2 (quality gates):**
- Add `pytest-cov`, measure coverage, set a floor in CI (the suite is broad; a number would
  catch regressions in the apps-stall zone).
- Add a real TestClient integration lane that boots `app:app` once (env-stubbed) and exercises
  `/api/health`, `/api/version`, auth-gated routes, and a forced-500 path end-to-end.

**Tier 3 (larger, fights-upstream — schedule deliberately):**
- Triage the 191 `except Exception: pass` handlers; convert the ones on data paths to log +
  re-raise or narrow the caught type. Do per-module, not en masse.
- Introduce a type checker (start with `ruff`'s slow-roll plan already noted in pyproject, or
  a scoped mypy on `core/` + `src/` first).
- Add a metrics endpoint (Prometheus/OTLP) if telemachus moves toward unattended fleet use.

**Tier 4 (docs):**
- Document the rollback path (pin previous image tag / `docker compose` redeploy).
- Re-run `@license-auditor` for a fresh `license-audit.md`.
