"""Tests for setup.seed_default_endpoint — opt-in, no-clobber, hermetic.

core.database is bound to sqlite:///:memory: by conftest; SQLite memory uses a
single shared connection per thread, so create_all + SessionLocal in-test see the
same tables. Network (probe / resolve) and settings I/O are monkeypatched.
"""
import json
import sys

import pytest

import setup


@pytest.fixture
def inmem_db():
    import importlib

    # A prior test may have left a raw fake core.database in sys.modules (several
    # regression tests stub it without teardown). Force the real module so engine /
    # SessionLocal / ModelEndpoint are genuine, then give it a clean schema (the
    # shared :memory: engine may also carry rows from another test).
    cur = sys.modules.get("core.database")
    if cur is None or not getattr(cur, "__file__", None):
        sys.modules.pop("core.database", None)
    cdb = importlib.import_module("core.database")
    cdb.Base.metadata.drop_all(bind=cdb.engine)
    cdb.Base.metadata.create_all(bind=cdb.engine)
    yield cdb
    cdb.Base.metadata.drop_all(bind=cdb.engine)


def test_seed_off_is_noop_and_never_touches_db(monkeypatch):
    monkeypatch.delenv("TELEMACHUS_SEED_DEFAULT_ENDPOINT", raising=False)
    import core.database as cdb

    def _boom(*a, **k):
        raise AssertionError("SessionLocal must not be called when seeding is off")

    monkeypatch.setattr(cdb, "SessionLocal", _boom)
    setup.seed_default_endpoint()  # returns before touching the DB


def test_seed_creates_shared_default_endpoint(monkeypatch, inmem_db):
    monkeypatch.setenv("TELEMACHUS_SEED_DEFAULT_ENDPOINT", "1")
    monkeypatch.setenv("OLLAMA_BASE_URL", "http://snowman:11434/v1")

    import src.endpoint_resolver as er
    monkeypatch.setattr(er, "resolve_url", lambda u: u)  # no DNS/tailscale in tests

    # Pin routes.model_routes in sys.modules and patch the prober THERE, so the
    # seeder's `from routes.model_routes import _probe_endpoint` resolves to our
    # stub regardless of any re-import another test triggered (otherwise the real
    # prober runs, hits the network, returns [], and cached_models is None).
    import importlib
    mr = importlib.import_module("routes.model_routes")
    monkeypatch.setitem(sys.modules, "routes.model_routes", mr)
    monkeypatch.setattr(mr, "_probe_endpoint", lambda url, key, timeout=3: ["qwen2.5:7b", "llama3.1:8b"])

    saved = {}
    import src.settings as st
    monkeypatch.setattr(st, "load_settings", lambda: dict(saved))
    monkeypatch.setattr(st, "save_settings", lambda s: saved.update(s))

    setup.seed_default_endpoint()

    cdb = inmem_db
    db = cdb.SessionLocal()
    try:
        eps = db.query(cdb.ModelEndpoint).all()
        assert len(eps) == 1
        ep = eps[0]
        ep_id = ep.id
        assert ep.base_url == "http://snowman:11434/v1"
        assert ep.owner is None  # shared
        assert ep.is_enabled is True
        assert json.loads(ep.cached_models) == ["qwen2.5:7b", "llama3.1:8b"]
    finally:
        db.close()

    assert saved["default_endpoint_id"] == ep_id
    assert saved["default_model"] == "qwen2.5:7b"


def test_seed_does_not_clobber_existing(monkeypatch, inmem_db):
    monkeypatch.setenv("TELEMACHUS_SEED_DEFAULT_ENDPOINT", "1")
    cdb = inmem_db
    db = cdb.SessionLocal()
    try:
        db.add(cdb.ModelEndpoint(id="existing", name="mine", base_url="http://x:1/v1", is_enabled=True))
        db.commit()
    finally:
        db.close()

    import routes.model_routes as mr

    def _boom(*a, **k):
        raise AssertionError("must not probe when an endpoint already exists")

    monkeypatch.setattr(mr, "_probe_endpoint", _boom)

    setup.seed_default_endpoint()  # skips

    db = cdb.SessionLocal()
    try:
        assert db.query(cdb.ModelEndpoint).count() == 1
    finally:
        db.close()
