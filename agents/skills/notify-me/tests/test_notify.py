import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

NOTIFY_SPEC = importlib.util.spec_from_file_location("notify", SCRIPTS / "notify.py")
notify = importlib.util.module_from_spec(NOTIFY_SPEC)
assert NOTIFY_SPEC.loader is not None
sys.modules["notify"] = notify
NOTIFY_SPEC.loader.exec_module(notify)

SETUP_SPEC = importlib.util.spec_from_file_location("notify_setup", SCRIPTS / "setup.py")
setup = importlib.util.module_from_spec(SETUP_SPEC)
assert SETUP_SPEC.loader is not None
SETUP_SPEC.loader.exec_module(setup)


class FakeResponse:
    def __init__(self, status, payload):
        self.status = status
        self.payload = payload

    def read(self):
        return json.dumps(self.payload).encode("utf-8")


class FakeConnection:
    def __init__(self, response):
        self.response = response
        self.request_args = None
        self.closed = False

    def request(self, *args, **kwargs):
        self.request_args = (args, kwargs)

    def getresponse(self):
        return self.response

    def close(self):
        self.closed = True


class SecretsTests(unittest.TestCase):
    def test_parse_secrets_accepts_common_env_forms(self):
        values = notify.parse_secrets(
            "# telegram\nexport TELEGRAM_BOT_TOKEN='123456:abcdefghijklmnopqrstuvwxyz'\n"
            'TELEGRAM_CHAT_ID="-100123456"\n'
        )

        self.assertEqual(values[notify.BOT_TOKEN_KEY], "123456:abcdefghijklmnopqrstuvwxyz")
        self.assertEqual(values[notify.CHAT_ID_KEY], "-100123456")

    def test_parse_secrets_rejects_shell_commands(self):
        with self.assertRaisesRegex(notify.NotifyError, "expected KEY=value"):
            notify.parse_secrets("source ~/.profile\n")

    def test_load_config_requires_private_permissions(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / ".secrets"
            path.write_text(
                "TELEGRAM_BOT_TOKEN=123456:abcdefghijklmnopqrstuvwxyz\n"
                "TELEGRAM_CHAT_ID=-100123456\n",
                encoding="utf-8",
            )
            path.chmod(0o644)

            with self.assertRaisesRegex(notify.NotifyError, "permissions are too open"):
                notify.load_config(path)

    def test_upsert_preserves_unrelated_values_and_removes_duplicates(self):
        updated = setup.upsert_secrets(
            "OTHER_SECRET=keep\nTELEGRAM_CHAT_ID=1\nTELEGRAM_CHAT_ID=2\n",
            {
                notify.BOT_TOKEN_KEY: "123456:abcdefghijklmnopqrstuvwxyz",
                notify.CHAT_ID_KEY: "-100123456",
            },
        )

        self.assertIn("OTHER_SECRET=keep", updated)
        self.assertEqual(updated.count("TELEGRAM_CHAT_ID="), 1)
        self.assertIn("TELEGRAM_CHAT_ID=-100123456", updated)
        self.assertIn("TELEGRAM_BOT_TOKEN=123456:abcdefghijklmnopqrstuvwxyz", updated)

    def test_write_secrets_uses_private_permissions(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / ".env" / ".secrets"

            setup.write_secrets(path, "TELEGRAM_CHAT_ID=-100123456\n")

            self.assertEqual(os.stat(path).st_mode & 0o777, 0o600)


class NotificationTests(unittest.TestCase):
    def test_send_notification_posts_to_telegram(self):
        connection = FakeConnection(FakeResponse(200, {"ok": True, "result": {"message_id": 42}}))

        message_id = notify.send_notification(
            "123456:abcdefghijklmnopqrstuvwxyz",
            "-100123456",
            "Production API is unhealthy",
            connection_factory=lambda *args, **kwargs: connection,
        )

        self.assertEqual(message_id, 42)
        self.assertTrue(connection.closed)
        request_args, request_kwargs = connection.request_args
        self.assertEqual(request_args[0], "POST")
        self.assertIn("/bot123456:abcdefghijklmnopqrstuvwxyz/sendMessage", request_args[1])
        self.assertIn("Production+API+is+unhealthy", request_kwargs["body"])

    def test_send_error_does_not_include_token(self):
        connection = FakeConnection(
            FakeResponse(401, {"ok": False, "description": "Unauthorized"})
        )

        with self.assertRaisesRegex(notify.NotifyError, "HTTP 401: Unauthorized") as raised:
            notify.send_notification(
                "123456:abcdefghijklmnopqrstuvwxyz",
                "-100123456",
                "test",
                connection_factory=lambda *args, **kwargs: connection,
            )

        self.assertNotIn("123456:abcdefghijklmnopqrstuvwxyz", str(raised.exception))

    def test_message_limit_is_enforced(self):
        with self.assertRaisesRegex(notify.NotifyError, "Telegram allows 4096"):
            notify.validate_message("x" * 4097)


if __name__ == "__main__":
    unittest.main()
