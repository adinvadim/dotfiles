#!/usr/bin/env python3
"""Send one Telegram notification without exposing its credentials."""

from __future__ import annotations

import argparse
import http.client
import json
import os
from pathlib import Path
import re
import stat
import sys
from typing import Callable, Dict, Optional, Sequence, Tuple
from urllib.parse import urlencode


DEFAULT_SECRETS_FILE = Path.home() / ".env" / ".secrets"
BOT_TOKEN_KEY = "TELEGRAM_BOT_TOKEN"
CHAT_ID_KEY = "TELEGRAM_CHAT_ID"
MAX_MESSAGE_LENGTH = 4096
TOKEN_RE = re.compile(r"^\d+:[A-Za-z0-9_-]{20,}$")
CHAT_ID_RE = re.compile(r"^-?\d+$")
ENV_LINE_RE = re.compile(r"^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$")


class NotifyError(RuntimeError):
    pass


def parse_secrets(contents: str) -> Dict[str, str]:
    values: Dict[str, str] = {}
    for line_number, raw_line in enumerate(contents.splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        match = ENV_LINE_RE.match(line)
        if not match:
            raise NotifyError(f"invalid secrets syntax on line {line_number}; expected KEY=value")
        key, value = match.groups()
        if key in values:
            raise NotifyError(f"duplicate key {key} in secrets file")
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        values[key] = value
    return values


def validate_config(bot_token: str, chat_id: str) -> Tuple[str, str]:
    if not TOKEN_RE.fullmatch(bot_token):
        raise NotifyError(f"{BOT_TOKEN_KEY} is not a Telegram BotFather token")
    if not CHAT_ID_RE.fullmatch(chat_id):
        raise NotifyError(f"{CHAT_ID_KEY} must be a numeric Telegram chat id")
    return bot_token, chat_id


def load_config(path: Path = DEFAULT_SECRETS_FILE) -> Tuple[str, str]:
    if path.is_symlink():
        raise NotifyError(f"refusing symlinked secrets file: {path}")
    try:
        file_stat = path.stat()
    except FileNotFoundError as exc:
        raise NotifyError(f"secrets file not found: {path}") from exc
    if not stat.S_ISREG(file_stat.st_mode):
        raise NotifyError(f"secrets path is not a regular file: {path}")
    if hasattr(os, "getuid") and file_stat.st_uid != os.getuid():
        raise NotifyError(f"secrets file is not owned by the current user: {path}")
    if stat.S_IMODE(file_stat.st_mode) & 0o077:
        raise NotifyError(f"secrets file permissions are too open; run: chmod 600 {path}")

    values = parse_secrets(path.read_text(encoding="utf-8"))
    missing = [key for key in (BOT_TOKEN_KEY, CHAT_ID_KEY) if not values.get(key)]
    if missing:
        raise NotifyError(f"missing {', '.join(missing)} in {path}")
    return validate_config(values[BOT_TOKEN_KEY], values[CHAT_ID_KEY])


def validate_message(message: str) -> str:
    message = message.strip()
    if not message:
        raise NotifyError("notification message is empty")
    if len(message) > MAX_MESSAGE_LENGTH:
        raise NotifyError(
            f"notification is {len(message)} characters; Telegram allows {MAX_MESSAGE_LENGTH}"
        )
    return message


def send_notification(
    bot_token: str,
    chat_id: str,
    message: str,
    *,
    timeout: float = 15,
    connection_factory: Callable[..., http.client.HTTPSConnection] = http.client.HTTPSConnection,
) -> Optional[int]:
    payload = urlencode(
        {
            "chat_id": chat_id,
            "text": validate_message(message),
            "disable_web_page_preview": "true",
        }
    )
    connection = connection_factory("api.telegram.org", timeout=timeout)
    try:
        connection.request(
            "POST",
            f"/bot{bot_token}/sendMessage",
            body=payload,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        response = connection.getresponse()
        response_body = response.read()
    except OSError as exc:
        raise NotifyError(f"Telegram connection failed: {exc}") from exc
    finally:
        connection.close()

    try:
        decoded = json.loads(response_body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise NotifyError(f"Telegram returned HTTP {response.status} with an invalid response") from exc

    if response.status < 200 or response.status >= 300 or decoded.get("ok") is not True:
        description = decoded.get("description")
        detail = description if isinstance(description, str) else "request rejected"
        raise NotifyError(f"Telegram returned HTTP {response.status}: {detail}")

    result = decoded.get("result")
    message_id = result.get("message_id") if isinstance(result, dict) else None
    return message_id if isinstance(message_id, int) else None


def read_message(args: argparse.Namespace) -> str:
    if args.message is not None:
        return validate_message(args.message)
    if args.message_file is not None:
        try:
            return validate_message(args.message_file.read_text(encoding="utf-8"))
        except OSError as exc:
            raise NotifyError(f"cannot read message file: {args.message_file}") from exc
    if sys.stdin.isatty():
        raise NotifyError("pass --message, --message-file, or pipe the message on standard input")
    return validate_message(sys.stdin.read())


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--secrets-file", type=Path, default=DEFAULT_SECRETS_FILE)
    parser.add_argument("--check", action="store_true", help="validate credentials without sending")
    message = parser.add_mutually_exclusive_group()
    message.add_argument("--message")
    message.add_argument("--message-file", type=Path)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        bot_token, chat_id = load_config(args.secrets_file)
        if args.check:
            print("Telegram notification configuration is valid.")
            return 0
        message_id = send_notification(bot_token, chat_id, read_message(args))
    except NotifyError as exc:
        print(f"notify-me: {exc}", file=sys.stderr)
        return 1

    suffix = f" (message_id={message_id})" if message_id is not None else ""
    print(f"Telegram notification sent{suffix}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
