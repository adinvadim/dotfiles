#!/usr/bin/env python3
"""Configure notify-me credentials in ~/.env/.secrets."""

from __future__ import annotations

import getpass
import os
from pathlib import Path
import re
import sys
import tempfile
from typing import Dict, Optional

import notify


ASSIGNMENT_RE = re.compile(r"^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=")


def upsert_secrets(contents: str, replacements: Dict[str, str]) -> str:
    output = []
    written = set()
    for raw_line in contents.splitlines():
        match = ASSIGNMENT_RE.match(raw_line.strip())
        key = match.group(1) if match else None
        if key not in replacements:
            output.append(raw_line)
            continue
        if key not in written:
            output.append(f"{key}={replacements[key]}")
            written.add(key)

    if output and output[-1] != "":
        output.append("")
    for key, value in replacements.items():
        if key not in written:
            output.append(f"{key}={value}")
    return "\n".join(output).rstrip("\n") + "\n"


def existing_values(path: Path) -> Dict[str, str]:
    if not path.exists():
        return {}
    if path.is_symlink():
        raise notify.NotifyError(f"refusing symlinked secrets file: {path}")
    return notify.parse_secrets(path.read_text(encoding="utf-8"))


def write_secrets(path: Path, contents: str) -> None:
    if path.is_symlink():
        raise notify.NotifyError(f"refusing symlinked secrets file: {path}")
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=".notify-me-", dir=str(path.parent))
    temporary_path = Path(temporary_name)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as temporary_file:
            temporary_file.write(contents)
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.replace(str(temporary_path), str(path))
        path.chmod(0o600)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def prompt_value(prompt: str, current: Optional[str], *, secret: bool = False) -> str:
    suffix = " [leave blank to keep current]" if current else ""
    reader = getpass.getpass if secret else input
    value = reader(f"{prompt}{suffix}: ").strip()
    if value:
        return value
    if current:
        return current
    raise notify.NotifyError(f"{prompt} is required")


def main() -> int:
    path = notify.DEFAULT_SECRETS_FILE
    try:
        values = existing_values(path)
        bot_token = prompt_value(
            "Telegram BotFather token",
            values.get(notify.BOT_TOKEN_KEY),
            secret=True,
        )
        chat_id = prompt_value("Telegram numeric chat id", values.get(notify.CHAT_ID_KEY))
        notify.validate_config(bot_token, chat_id)
        contents = path.read_text(encoding="utf-8") if path.exists() else ""
        updated = upsert_secrets(
            contents,
            {
                notify.BOT_TOKEN_KEY: bot_token,
                notify.CHAT_ID_KEY: chat_id,
            },
        )
        write_secrets(path, updated)
        notify.load_config(path)
    except (OSError, notify.NotifyError) as exc:
        print(f"notify-me setup: {exc}", file=sys.stderr)
        return 1

    print(f"Saved Telegram credentials to {path} with mode 0600.")
    print("Run python3 ~/.agents/skills/notify-me/scripts/notify.py --check to validate it.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
