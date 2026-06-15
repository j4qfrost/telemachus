"""Pin the session-summary extraction used by the always-visible summary bar.

`GET /api/session/{id}/summary` surfaces the latest compaction summary so the
chat UI can keep the "what / next" context in front of the user (mirrors the
Claude Code statusline footer). The route is a thin wrapper around the pure
helper `_extract_latest_summary`; these tests pin its behaviour against the two
content shapes compaction emits and the visible marker it must ignore.
"""
import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")

from routes.session_routes import _extract_latest_summary


class _Msg:
    """Minimal stand-in for core.models.ChatMessage (role/content/metadata)."""

    def __init__(self, role="system", content="", metadata=None):
        self.role = role
        self.content = content
        self.metadata = metadata


def test_extracts_manual_compact_form():
    # Form written by POST /session/{id}/compact.
    history = [
        _Msg("user", "hello", None),
        _Msg(
            "system",
            "[Conversation summary]\n## Conversation Summary\n### User Goal\nShip kindling.",
            {"compacted": True, "summarized_count": 12, "timestamp": "2026-06-14T00:00:00"},
        ),
    ]
    body, ts, count = _extract_latest_summary(history)
    assert body.startswith("## Conversation Summary")
    assert ts == "2026-06-14T00:00:00"
    assert count == 12


def test_extracts_auto_compact_form_with_bracketed_count():
    # Form written by the auto-compactor / history_routes (count in the header).
    history = [
        _Msg(
            "system",
            "[Conversation summary — 12 earlier messages were compacted]\n\n## Summary\nGoal: X",
            {"compacted": True},
        ),
    ]
    body, _, _ = _extract_latest_summary(history)
    assert body == "## Summary\nGoal: X"


def test_ignores_visible_marker_message():
    # The "**Conversation compacted**" banner is flagged compacted but has no
    # summary body — it must not be surfaced.
    history = [
        _Msg("system", "**Conversation compacted** — 12 summarized, 8 kept.", {"compacted": True}),
    ]
    assert _extract_latest_summary(history) == (None, None, None)


def test_ignores_non_compacted_messages():
    history = [_Msg("assistant", "[Conversation summary] not really", None)]
    assert _extract_latest_summary(history) == (None, None, None)


def test_returns_most_recent_summary():
    history = [
        _Msg("system", "[Conversation summary]\nOLD", {"compacted": True}),
        _Msg("user", "more chat", None),
        _Msg("system", "[Conversation summary]\nNEW", {"compacted": True}),
    ]
    body, _, _ = _extract_latest_summary(history)
    assert body == "NEW"


def test_empty_history_is_safe():
    assert _extract_latest_summary([]) == (None, None, None)
    assert _extract_latest_summary(None) == (None, None, None)
