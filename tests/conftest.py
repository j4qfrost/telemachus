"""Shared test configuration — ensure project root is on sys.path and stub heavy deps."""
import sys
import os
import types
import importlib.util
from unittest.mock import MagicMock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Tests must never touch a real on-disk database. core.database binds its engine
# at import time from DATABASE_URL, so pin in-memory SQLite before anything imports
# it. setdefault so an explicit override (e.g. a future integration lane) still wins.
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")


def _has_module(mod_name: str) -> bool:
    try:
        return importlib.util.find_spec(mod_name) is not None
    except (ImportError, ValueError):
        return False


# Stub optional dependencies only when they are not installed. Do not replace
# real FastAPI/Starlette/Pydantic modules: route tests import their subpackages.
for mod_name in [
    "sqlalchemy", "sqlalchemy.orm", "sqlalchemy.types", "sqlalchemy.ext", "sqlalchemy.ext.declarative",
    "sqlalchemy.ext.hybrid", "sqlalchemy.sql", "sqlalchemy.sql.expression",
    "sqlalchemy.sql.sqltypes", "bcrypt", "pyotp",
    "httpx", "fastapi", "fastapi.responses", "fastapi.routing",
    "starlette", "starlette.responses", "starlette.middleware", "starlette.middleware.base",
    "pydantic",
]:
    if mod_name not in sys.modules and not _has_module(mod_name):
        sys.modules[mod_name] = MagicMock()

# Cache the REAL core.database up front (it imports cleanly now that sqlalchemy is
# present). Per-file stubs that only install a fake "when core.database is absent"
# (tests/test_model_routes.py) then become no-ops, so they can no longer leak a
# MagicMock'd core.database into a later test — the collection-time pollution that
# made tests/test_session_mode_helpers.py order-dependent and red.
if _has_module("sqlalchemy"):
    try:
        import core.database  # noqa: F401
    except Exception:
        pass

if "src.database" not in sys.modules:
    _db = types.ModuleType("src.database")
    _db.SessionLocal = MagicMock()
    _db.ModelEndpoint = MagicMock()
    sys.modules["src.database"] = _db
