"""Non-blocking Telegram monitoring for the local agent run.

Usage:
    from muscle_mem.utils.telegram_notifier import init_notifier, get_notifier

    notifier = init_notifier(bot_token="...", chat_id="...")
    notifier.send_text("Hello from agent")
    notifier.send_photo(screenshot_bytes, caption="Step 1/15")

If TG_BOT_TOKEN / TG_CHAT_ID env vars or CLI args are not provided,
get_notifier() returns None and all callers silently skip sending.
"""

import logging
import queue
import threading
from typing import Any, Optional

import httpx

_notifier: Optional["TelegramNotifier"] = None


def init_notifier(bot_token: str, chat_id: str) -> "TelegramNotifier":
    global _notifier
    _notifier = TelegramNotifier(bot_token, chat_id)
    return _notifier


def get_notifier() -> Optional["TelegramNotifier"]:
    return _notifier


def _split_text(text: str, limit: int = 4096) -> list[str]:
    """Split text into chunks no longer than limit characters."""
    return [text[i : i + limit] for i in range(0, len(text), limit)]


class TelegramNotifier:
    """Sends messages to a Telegram chat via Bot API using a background thread."""

    def __init__(self, bot_token: str, chat_id: str) -> None:
        self.bot_token = bot_token
        self.chat_id = str(chat_id)
        self._queue: queue.Queue = queue.Queue()
        self._thread = threading.Thread(target=self._worker, daemon=True, name="tg-notifier")
        self._thread.start()

    # ------------------------------------------------------------------
    # Public API (called from main thread; non-blocking)
    # ------------------------------------------------------------------

    def send_text(self, text: str) -> None:
        if text and text.strip():
            self._queue.put(("text", text))

    def send_photo(self, image_bytes: bytes, caption: str = "") -> None:
        self._queue.put(("photo", image_bytes, caption))

    def on_usage(self, model: str, usage: Any) -> None:
        """Usage hook registered with engine.register_usage_hook()."""
        if usage is None:
            return
        input_tokens = getattr(usage, "input_tokens", None) or getattr(usage, "prompt_tokens", None)
        output_tokens = getattr(usage, "output_tokens", None) or getattr(usage, "completion_tokens", None)
        cache_read = getattr(usage, "cache_read_input_tokens", None)
        parts = [f"[USAGE] model={model}"]
        if input_tokens is not None:
            parts.append(f"in={input_tokens}")
        if output_tokens is not None:
            parts.append(f"out={output_tokens}")
        if cache_read:
            parts.append(f"cache_read={cache_read}")
        self.send_text("  ".join(parts))

    # ------------------------------------------------------------------
    # Background worker
    # ------------------------------------------------------------------

    def _worker(self) -> None:
        while True:
            try:
                item = self._queue.get()
                kind = item[0]
                if kind == "text":
                    self._do_send_text(item[1])
                elif kind == "photo":
                    self._do_send_photo(item[1], item[2])
            except Exception:
                pass  # never crash the daemon thread

    def _do_send_text(self, text: str) -> None:
        url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
        for chunk in _split_text(text, 4096):
            try:
                httpx.post(
                    url,
                    json={"chat_id": self.chat_id, "text": chunk},
                    timeout=10,
                )
            except Exception:
                pass

    def _do_send_photo(self, image_bytes: bytes, caption: str) -> None:
        url = f"https://api.telegram.org/bot{self.bot_token}/sendPhoto"
        try:
            httpx.post(
                url,
                data={"chat_id": self.chat_id, "caption": caption[:1024]},
                files={"photo": ("screenshot.png", image_bytes, "image/png")},
                timeout=20,
            )
        except Exception:
            pass


class TelegramLogHandler(logging.Handler):
    """Logging handler that forwards records to the active TelegramNotifier."""

    def emit(self, record: logging.LogRecord) -> None:
        notifier = get_notifier()
        if notifier is None:
            return
        try:
            msg = self.format(record)
            notifier.send_text(f"[{record.levelname}] {record.name}: {msg}")
        except Exception:
            self.handleError(record)
