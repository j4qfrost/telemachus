#!/usr/bin/env python3
"""Telemachus — first-time setup script.

Creates data directories, initializes the database, and sets up an
initial admin user. Safe to re-run (skips what already exists).
"""

import os
import shutil
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")

DIRS = [
    DATA_DIR,
    os.path.join(DATA_DIR, "uploads"),
    os.path.join(DATA_DIR, "personal_docs"),
    os.path.join(DATA_DIR, "personal_uploads"),
    os.path.join(DATA_DIR, "tts_cache"),
    os.path.join(DATA_DIR, "generated_images"),
    os.path.join(DATA_DIR, "deep_research"),
    os.path.join(DATA_DIR, "chroma"),
    os.path.join(DATA_DIR, "rag"),
    os.path.join(DATA_DIR, "memory_vectors"),
    os.path.join(BASE_DIR, "logs"),
]


def create_dirs():
    for d in DIRS:
        os.makedirs(d, exist_ok=True)
        print(f"  [ok] {os.path.relpath(d, BASE_DIR)}/")


def init_database():
    """Create all SQLAlchemy tables."""
    sys.path.insert(0, BASE_DIR)
    os.environ.setdefault("DATABASE_URL", f"sqlite:///{os.path.join(DATA_DIR, 'app.db')}")

    from core.database import Base, engine
    Base.metadata.create_all(bind=engine)
    print("  [ok] Database initialized")


def create_default_admin():
    """Create an initial admin user if none exists."""
    auth_path = os.path.join(DATA_DIR, "auth.json")
    if os.path.exists(auth_path):
        print("  [skip] auth.json already exists")
        return

    try:
        import bcrypt
        import json

        username = os.getenv("ODYSSEUS_ADMIN_USER", "admin").strip() or "admin"
        password = os.getenv("ODYSSEUS_ADMIN_PASSWORD") or __import__("secrets").token_urlsafe(18)
        hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
        auth_data = {
            "users": {
                username: {
                    "password_hash": hashed,
                    "is_admin": True,
                }
            }
        }
        with open(auth_path, "w", encoding="utf-8") as f:
            json.dump(auth_data, f, indent=2)
        print(f"  [ok] Initial admin user created ({username})")
        print(f"        Temporary password: {password}")
        print("        ** Change it after first login. Set ODYSSEUS_ADMIN_PASSWORD to choose your own. **")
    except ImportError:
        print("  [warn] bcrypt not installed — skipping admin user creation")
        print("         Run: pip install bcrypt")


def create_env():
    """Copy .env.example to .env if it doesn't exist."""
    env_path = os.path.join(BASE_DIR, ".env")
    example_path = os.path.join(BASE_DIR, ".env.example")
    if os.path.exists(env_path):
        print("  [skip] .env already exists")
        return
    if os.path.exists(example_path):
        import shutil
        shutil.copy2(example_path, env_path)
        print("  [ok] .env created from .env.example")
        print("        ** Edit .env with your LLM host and API keys **")
    else:
        print("  [warn] .env.example not found — create .env manually")


def seed_default_endpoint():
    """Optionally seed a shared snowman-Ollama model endpoint + default model.

    Opt-in via TELEMACHUS_SEED_DEFAULT_ENDPOINT=1 (off by default — upstream
    deliberately stopped auto-adding Ollama). No-op if any endpoint already
    exists, so it never clobbers an admin's configuration. Mirrors the UI's
    create_model_endpoint path so the row's invariants match.
    """
    if os.getenv("TELEMACHUS_SEED_DEFAULT_ENDPOINT", "").strip().lower() not in ("1", "true", "yes"):
        print("  [skip] endpoint seeding off (set TELEMACHUS_SEED_DEFAULT_ENDPOINT=1 to enable)")
        return

    sys.path.insert(0, BASE_DIR)
    import json
    import uuid

    from core.database import ModelEndpoint, SessionLocal
    from src.endpoint_resolver import normalize_base, resolve_url
    from src.settings import load_settings, save_settings

    base_url = os.getenv("OLLAMA_BASE_URL") or f"http://{os.getenv('LLM_HOST', 'snowman')}:11434/v1"
    base_url = resolve_url(normalize_base(base_url.strip().rstrip("/")))
    name = os.getenv("TELEMACHUS_SEED_ENDPOINT_NAME", "snowman-ollama")

    db = SessionLocal()
    try:
        if db.query(ModelEndpoint).first() is not None:
            print("  [skip] a model endpoint already exists — not seeding")
            return

        # Best-effort probe (short timeout); fine if the host is asleep right now —
        # discovery fills models later. Reuses the route's prober for identical behavior.
        model_ids = []
        try:
            from routes.model_routes import _probe_endpoint
            model_ids = _probe_endpoint(base_url, None, timeout=3) or []
        except Exception as e:
            print(f"  [warn] model probe failed ({e}); seeding endpoint without cached models")

        ep = ModelEndpoint(
            id=str(uuid.uuid4())[:8],
            name=name,
            base_url=base_url,
            api_key=None,
            is_enabled=True,
            model_type="llm",
            cached_models=json.dumps(model_ids) if model_ids else None,
            supports_tools=None,
            owner=None,  # shared (visible to all users)
        )
        db.add(ep)
        db.commit()

        settings = load_settings()
        if not settings.get("default_endpoint_id"):
            settings["default_endpoint_id"] = ep.id
            settings["default_model"] = model_ids[0] if model_ids else ""
            save_settings(settings)

        print(f"  [ok] Seeded endpoint '{name}' -> {base_url} ({len(model_ids)} models)")
        if model_ids:
            print(f"        default chat model: {model_ids[0]}")
        else:
            print("        no models probed yet — set a default in the UI once the host is reachable")
    finally:
        db.close()


def check_deps():
    """Check for common missing dependencies."""
    missing = []
    for mod in ["fastapi", "uvicorn", "sqlalchemy", "bcrypt", "httpx", "dotenv"]:
        try:
            __import__(mod)
        except ImportError:
            missing.append(mod)
    if missing:
        print(f"\n  [warn] Missing packages: {', '.join(missing)}")
        print("         Run: pip install -r requirements.txt")
    else:
        print("  [ok] All core dependencies installed")

    if os.name != "nt" and shutil.which("tmux") is None:
        print("\n  [warn] tmux not found")
        print("         Cookbook uses tmux for background downloads and model serves.")
        print("         Install it with your OS package manager, for example:")
        if sys.platform == "darwin":
            print("           brew install tmux")
        else:
            print("           sudo apt install tmux")
            print("           sudo pacman -S tmux")
            print("           sudo dnf install tmux")
    elif os.name != "nt":
        print("  [ok] tmux installed")


def main():
    print("\n=== Telemachus Setup ===\n")

    print("1. Creating directories...")
    create_dirs()

    print("\n2. Environment file...")
    create_env()

    print("\n3. Checking dependencies...")
    check_deps()

    print("\n4. Initializing database...")
    try:
        init_database()
    except Exception as e:
        print(f"  [warn] Database init failed: {e}")
        print("         This is OK if dependencies aren't installed yet.")

    print("\n5. Creating initial admin...")
    try:
        create_default_admin()
    except Exception as e:
        print(f"  [warn] Admin creation failed: {e}")

    print("\n6. Seeding default model endpoint...")
    try:
        seed_default_endpoint()
    except Exception as e:
        print(f"  [warn] Endpoint seeding failed: {e}")

    print("\n=== Setup complete ===")
    # start-macos.sh launches the server itself (on its own port) right after
    # this, so suppress the manual hint there to avoid a contradictory URL.
    if not os.getenv("ODYSSEUS_SKIP_RUN_HINT"):
        print("\nStart the server with:")
        print("  python -m uvicorn app:app --host 127.0.0.1 --port 7000")
        print("\nThen open http://localhost:7000")
    print("Login with the admin username and temporary password printed above.\n")


if __name__ == "__main__":
    main()
