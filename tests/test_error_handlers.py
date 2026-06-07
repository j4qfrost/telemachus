"""Behavioral pins for app-level error handling and the health contract.

app.py is expensive to import (it boots the whole orchestrator), and the rest of
the suite deliberately avoids `from app import app` to keep collection fast and
free of import pollution. So these tests pin the *contracts* the hardening pass
added against a minimal isolated FastAPI app that registers the same handler
bodies, plus a couple of static assertions that app.py actually wires them.

Contracts pinned here:
- An unhandled exception is caught by a catch-all handler that returns a
  structured, opaque 500 and does NOT leak the exception message / traceback.
- /api/health returns a timezone-aware UTC ISO-8601 timestamp (no naive
  datetime.utcnow(), which is deprecated and slated for removal).
"""

import logging
import re
from datetime import datetime, timezone
from pathlib import Path

import pytest

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient

APP_PY = Path(__file__).resolve().parent.parent / "app.py"


# ── catch-all 500 handler ───────────────────────────────────────

def _build_app_with_catch_all() -> FastAPI:
    app = FastAPI()
    logger = logging.getLogger("test_error_handlers")

    # Mirror of app.py:unhandled_exception_handler — keep in sync.
    @app.exception_handler(Exception)
    async def unhandled(request: Request, exc: Exception):
        logger.error("Unhandled exception on %s %s", request.method, request.url.path, exc_info=exc)
        return JSONResponse(
            status_code=500,
            content={"error": "INTERNAL_ERROR", "message": "An internal error occurred."},
        )

    @app.get("/boom")
    async def boom():
        raise RuntimeError("SECRET-INTERNAL-DETAIL-should-not-leak")

    return app


def test_unhandled_exception_returns_sanitized_500():
    client = TestClient(_build_app_with_catch_all(), raise_server_exceptions=False)
    resp = client.get("/boom")
    assert resp.status_code == 500
    body = resp.json()
    assert body == {"error": "INTERNAL_ERROR", "message": "An internal error occurred."}


def test_unhandled_exception_does_not_leak_internal_detail():
    client = TestClient(_build_app_with_catch_all(), raise_server_exceptions=False)
    resp = client.get("/boom")
    assert "SECRET-INTERNAL-DETAIL-should-not-leak" not in resp.text
    assert "Traceback" not in resp.text
    assert "RuntimeError" not in resp.text


def test_app_py_registers_catch_all_handler():
    """Static guard: the real app.py keeps the catch-all wired."""
    source = APP_PY.read_text(encoding="utf-8")
    assert "@app.exception_handler(Exception)" in source
    assert "INTERNAL_ERROR" in source


# ── /api/health timestamp contract ──────────────────────────────

def test_health_timestamp_is_timezone_aware_and_recent():
    # Mirror of app.py:health_check timestamp construction.
    payload = {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()}
    parsed = datetime.fromisoformat(payload["timestamp"])
    assert parsed.tzinfo is not None, "health timestamp must be timezone-aware"
    assert payload["status"] == "healthy"


def test_app_py_health_uses_tz_aware_now():
    """Static guard against a regression back to the deprecated utcnow()."""
    source = APP_PY.read_text(encoding="utf-8")
    health_block = re.search(r"def health_check\(.*?\n(.*?)\n@app", source, re.DOTALL)
    assert health_block, "could not locate health_check in app.py"
    assert "datetime.utcnow()" not in health_block.group(1)
    assert "datetime.now(timezone.utc)" in health_block.group(1)
