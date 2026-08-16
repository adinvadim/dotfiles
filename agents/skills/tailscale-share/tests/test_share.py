import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).parents[1] / "scripts" / "share.py"
SPEC = importlib.util.spec_from_file_location("tailscale_share", SCRIPT)
share = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(share)


class PublicationTests(unittest.TestCase):
    def test_single_file_urls(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "note.md"
            source.write_text("hello\n", encoding="utf-8")

            publication = share.stage_publication([source], root / "state")
            urls = share.publication_urls("machine.example.ts.net", publication)

            self.assertEqual(urls["url"], urls["download_url"])
            self.assertTrue(urls["url"].endswith("/note.md"))
            staged = share.content_root(root / "state") / publication["id"] / "note.md"
            self.assertEqual(staged.read_text(encoding="utf-8"), "hello\n")

    def test_directory_urls(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "site"
            source.mkdir()
            (source / "index.html").write_text("<h1>Hello</h1>", encoding="utf-8")

            publication = share.stage_publication([source], root / "state")
            urls = share.publication_urls("machine.example.ts.net", publication)

            self.assertTrue(urls["url"].endswith("/site/"))
            self.assertTrue(urls["download_url"].endswith("/site.zip"))
            archive = share.content_root(root / "state") / publication["id"] / "site.zip"
            self.assertTrue(archive.is_file())

    def test_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / "target.txt"
            target.write_text("secret", encoding="utf-8")
            link = root / "link.txt"
            link.symlink_to(target)

            with self.assertRaisesRegex(share.ShareError, "symlink"):
                share.stage_publication([link], root / "state")

    def test_reference_parser(self):
        share_id = "20260801T010203Z-0123abcd"
        url = f"https://machine.example.ts.net/.share/{share_id}/file.txt"
        self.assertEqual(share.share_id_from_reference(share_id), share_id)
        self.assertEqual(share.share_id_from_reference(url), share_id)


class ServeConfigTests(unittest.TestCase):
    def test_mount_handlers(self):
        handler = {"Proxy": "http://127.0.0.1:47839"}
        status = {
            "Web": {
                "machine.example.ts.net:443": {
                    "Handlers": {"/": {"Proxy": "http://127.0.0.1:8437"}, "/.share/": handler}
                }
            }
        }
        self.assertEqual(share.find_mount(status, "machine.example.ts.net"), handler)


if __name__ == "__main__":
    unittest.main()
