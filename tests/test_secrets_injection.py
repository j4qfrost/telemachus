"""PR-5: secret injection — render-secrets.sh + opt-in Fernet app key.

render-secrets.sh is exercised as a subprocess with a fake backend binary on
PATH (no real sigil/rbw). The Fernet key path is tested against a tmp key file.
"""
import os
import stat
import subprocess
from pathlib import Path

import pytest
from cryptography.fernet import Fernet

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts" / "render-secrets.sh"


@pytest.fixture
def fake_backend(tmp_path):
    """Put fake `sigil` and `rbw` on PATH that echo a deterministic value."""
    for name in ("sigil", "rbw"):
        p = tmp_path / name
        # sigil read <ref> / rbw get <ref>  -> "<name>:<ref>"
        p.write_text('#!/bin/sh\necho "%s:$2"\n' % name)
        p.chmod(0o755)
    return {**os.environ, "PATH": f"{tmp_path}:{os.environ['PATH']}"}


def _run(env, *args):
    return subprocess.run([str(SCRIPT), *args], capture_output=True, text=True, env=env)


def test_noop_without_backend():
    env = {**os.environ}
    env.pop("SECRET_BACKEND", None)
    r = _run(env, "--export")
    assert r.returncode == 0
    assert r.stdout.strip() == ""


def test_export_only_configured_vars(fake_backend):
    env = {**fake_backend, "SECRET_BACKEND": "rbw",
           "TELEMACHUS_SECRET_OPENAI_API_KEY": "telemachus/openai"}
    env.pop("TELEMACHUS_SECRET_SEARXNG_SECRET", None)
    r = _run(env, "--export")
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "export OPENAI_API_KEY='rbw:telemachus/openai'"
    # An unconfigured var is not emitted.
    assert "SEARXNG_SECRET" not in r.stdout


def test_envfile_is_locked_down(fake_backend, tmp_path):
    out = tmp_path / "secrets.env"
    env = {**fake_backend, "SECRET_BACKEND": "sigil",
           "TELEMACHUS_SECRET_SEARXNG_SECRET": "op://s/secret"}
    r = _run(env, "--envfile", str(out))
    assert r.returncode == 0, r.stderr
    assert out.read_text().strip() == "SEARXNG_SECRET=sigil:op://s/secret"
    assert stat.S_IMODE(out.stat().st_mode) == 0o600


def test_unknown_backend_fails(fake_backend):
    env = {**fake_backend, "SECRET_BACKEND": "bogus",
           "TELEMACHUS_SECRET_OPENAI_API_KEY": "x"}
    r = _run(env, "--export")
    assert r.returncode != 0
    assert "unknown SECRET_BACKEND" in r.stderr


# ── opt-in Fernet app key ──

@pytest.fixture
def fresh_key_path(tmp_path, monkeypatch):
    from src import secret_storage as ss
    monkeypatch.setattr(ss, "_KEY_PATH", tmp_path / ".app_key")
    monkeypatch.setattr(ss, "_fernet", None)
    return ss


def test_injected_key_used_on_fresh_install(fresh_key_path, monkeypatch):
    ss = fresh_key_path
    key = Fernet.generate_key().decode()
    monkeypatch.setenv("TELEMACHUS_APP_KEY", key)
    got = ss._load_or_create_key()
    assert got == key.encode("ascii")
    assert ss._KEY_PATH.read_bytes() == key.encode("ascii")


def test_invalid_injected_key_raises(fresh_key_path, monkeypatch):
    ss = fresh_key_path
    monkeypatch.setenv("TELEMACHUS_APP_KEY", "not-a-valid-fernet-key")
    with pytest.raises(RuntimeError, match="valid Fernet key"):
        ss._load_or_create_key()


def test_existing_key_never_overwritten(fresh_key_path, monkeypatch):
    ss = fresh_key_path
    existing = Fernet.generate_key()
    ss._KEY_PATH.write_bytes(existing)
    # Even with an injected key set, an existing file wins (no clobber).
    monkeypatch.setenv("TELEMACHUS_APP_KEY", Fernet.generate_key().decode())
    assert ss._load_or_create_key() == existing


def test_generates_when_unset(fresh_key_path, monkeypatch):
    ss = fresh_key_path
    monkeypatch.delenv("TELEMACHUS_APP_KEY", raising=False)
    got = ss._load_or_create_key()
    assert Fernet(got)  # valid generated key
    assert ss._KEY_PATH.exists()
