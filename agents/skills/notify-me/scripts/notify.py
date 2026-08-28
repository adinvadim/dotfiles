#!/usr/bin/env python3
"""Configure or send a Telegram notification."""

import argparse
import getpass
import http.client
import json
from pathlib import Path
import sys
import tempfile
from urllib.parse import urlencode


SECRETS = Path.home() / ".env" / ".secrets"
BOT_TOKEN = "TELEGRAM_BOT_TOKEN"
CHAT_ID = "TELEGRAM_CHAT_ID"


def fail(message):
    raise SystemExit(f"notify-me: {message}")


def env_key(line):
    return line.partition("=")[0].removeprefix("export ").strip()


def parse_secrets(contents):
    values = {}
    for line in contents.splitlines():
        _, separator, value = line.partition("=")
        key = env_key(line)
        if separator and key in {BOT_TOKEN, CHAT_ID}:
            value = value.strip()
            if len(value) > 1 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            values[key] = value
    return values


def configure():
    token = getpass.getpass("Telegram BotFather token: ").strip()
    chat_id = input("Telegram numeric chat id: ").strip()
    if not token or not chat_id:
        fail("both values are required")

    existing = SECRETS.read_text(encoding="utf-8").splitlines() if SECRETS.exists() else []
    keys = {BOT_TOKEN, CHAT_ID}
    preserved = [line for line in existing if env_key(line) not in keys]
    contents = "\n".join(preserved + [f"{BOT_TOKEN}={token}", f"{CHAT_ID}={chat_id}"]) + "\n"

    SECRETS.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=SECRETS.parent, delete=False) as temporary:
        temporary.write(contents)
        temporary_path = Path(temporary.name)
    temporary_path.chmod(0o600)
    temporary_path.replace(SECRETS)
    print(f"Saved Telegram credentials to {SECRETS} with mode 0600.")


def load_credentials():
    if not SECRETS.exists():
        fail(f"missing {SECRETS}; run notify.py --setup")
    if SECRETS.stat().st_mode & 0o077:
        fail(f"permissions are too open; run chmod 600 {SECRETS}")
    values = parse_secrets(SECRETS.read_text(encoding="utf-8"))
    if not values.get(BOT_TOKEN) or not values.get(CHAT_ID):
        fail(f"missing {BOT_TOKEN} or {CHAT_ID} in {SECRETS}")
    return values[BOT_TOKEN], values[CHAT_ID]


def send(message):
    token, chat_id = load_credentials()
    body = urlencode({"chat_id": chat_id, "text": message})
    connection = http.client.HTTPSConnection("api.telegram.org", timeout=15)
    try:
        connection.request(
            "POST",
            f"/bot{token}/sendMessage",
            body=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        response = connection.getresponse()
        result = json.loads(response.read())
    except (OSError, ValueError) as error:
        fail(f"Telegram request failed: {type(error).__name__}")
    finally:
        connection.close()

    if not isinstance(result, dict):
        fail("Telegram returned an invalid response")
    if result.get("ok") is not True:
        fail(result.get("description", "Telegram rejected the message"))
    print("Telegram notification sent.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--setup", action="store_true")
    args = parser.parse_args()
    if args.setup:
        configure()
        return
    message = sys.stdin.read().strip()
    if not message:
        fail("pass the message on standard input")
    send(message)


if __name__ == "__main__":
    main()
