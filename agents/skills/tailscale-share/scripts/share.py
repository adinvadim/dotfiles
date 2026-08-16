#!/usr/bin/env python3
"""Publish local artifacts to the current tailnet through one stable endpoint."""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import fcntl
import functools
import http.server
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socketserver
import subprocess
import sys
import time
from typing import Any, Dict, Iterator, List, Optional, Sequence, Tuple
from urllib.error import URLError
from urllib.parse import quote, unquote, urlparse
from urllib.request import Request, urlopen
import zipfile


VERSION = "1.0.0"
DEFAULT_PORT = 47839
MOUNT_PATH = "/.share"
HEALTH_PATH = "/.tailscale-share-health"
ID_RE = re.compile(r"^\d{8}T\d{6}Z-[0-9a-f]{8}$")


class ShareError(RuntimeError):
    pass


def data_root() -> Path:
    base = os.environ.get("XDG_DATA_HOME")
    if base:
        return Path(base).expanduser() / "tailscale-share"
    return Path.home() / ".local" / "share" / "tailscale-share"


def configured_port() -> int:
    raw = os.environ.get("TAILSCALE_SHARE_PORT", str(DEFAULT_PORT))
    try:
        port = int(raw)
    except ValueError as exc:
        raise ShareError(f"TAILSCALE_SHARE_PORT must be an integer, got {raw!r}") from exc
    if not 1 <= port <= 65535:
        raise ShareError(f"TAILSCALE_SHARE_PORT must be between 1 and 65535, got {port}")
    return port


def content_root(root: Optional[Path] = None) -> Path:
    return (root or data_root()) / "content"


def metadata_root(root: Optional[Path] = None) -> Path:
    return (root or data_root()) / "metadata"


def run(command: Sequence[str], *, timeout: int = 15) -> subprocess.CompletedProcess[str]:
    try:
        result = subprocess.run(
            list(command),
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
    except FileNotFoundError as exc:
        raise ShareError(f"required command not found: {command[0]}") from exc
    except subprocess.TimeoutExpired as exc:
        raise ShareError(f"command timed out: {' '.join(command)}") from exc
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        raise ShareError(f"{' '.join(command)} failed: {detail}")
    return result


def tailscale_identity() -> Tuple[str, Dict[str, Any]]:
    result = run(["tailscale", "status", "--json"])
    try:
        status = json.loads(result.stdout)
        self_status = status["Self"]
        hostname = self_status["DNSName"].rstrip(".")
    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        raise ShareError("tailscale status did not return a usable MagicDNS name") from exc
    if self_status.get("Online") is False:
        raise ShareError("this machine is offline in Tailscale")
    return hostname, status


def expected_proxy(port: int) -> str:
    return f"http://127.0.0.1:{port}"


def find_mount(status: Dict[str, Any], hostname: str) -> Optional[Dict[str, Any]]:
    web = status.get("Web") or {}
    host_config = web.get(f"{hostname}:443") or {}
    handlers = host_config.get("Handlers") or {}
    for candidate in (MOUNT_PATH, MOUNT_PATH + "/"):
        handler = handlers.get(candidate)
        if handler is not None:
            return handler
    return None


def ensure_serve(hostname: str, port: int) -> None:
    result = run(["tailscale", "serve", "status", "--json"])
    try:
        status = json.loads(result.stdout or "{}")
    except json.JSONDecodeError as exc:
        raise ShareError("tailscale serve status returned invalid JSON") from exc

    handler = find_mount(status, hostname)
    if handler is not None:
        actual = str(handler.get("Proxy", "")).rstrip("/")
        if actual != expected_proxy(port):
            raise ShareError(
                f"{MOUNT_PATH} is already served by {actual or 'another handler'}; "
                "refusing to overwrite it"
            )
        return

    run(
        [
            "tailscale",
            "serve",
            "--bg",
            "--yes",
            "--https=443",
            f"--set-path={MOUNT_PATH}",
            expected_proxy(port),
        ],
        timeout=30,
    )


class ShareHandler(http.server.SimpleHTTPRequestHandler):
    server_version = "tailscale-share/1"

    def do_GET(self) -> None:  # noqa: N802 - stdlib callback name
        if urlparse(self.path).path == HEALTH_PATH:
            payload = json.dumps({"service": "tailscale-share", "version": VERSION}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)
            return
        super().do_GET()

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()

    def log_message(self, format: str, *args: Any) -> None:
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), format % args))


class ShareServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def health(port: int, *, timeout: float = 0.4) -> bool:
    try:
        with urlopen(f"http://127.0.0.1:{port}{HEALTH_PATH}", timeout=timeout) as response:
            payload = json.load(response)
        return payload.get("service") == "tailscale-share"
    except (OSError, URLError, ValueError, json.JSONDecodeError):
        return False


@contextlib.contextmanager
def startup_lock(root: Path) -> Iterator[None]:
    root.mkdir(parents=True, exist_ok=True)
    lock_path = root / "startup.lock"
    with lock_path.open("a+") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


def start_daemon(root: Path, port: int) -> None:
    if health(port):
        return

    log_path = root / "server.log"
    script = Path(__file__).resolve()
    with log_path.open("ab") as log:
        subprocess.Popen(
            [sys.executable, str(script), "_daemon", "--port", str(port), "--root", str(root)],
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=log,
            start_new_session=True,
            close_fds=True,
        )

    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if health(port):
            return
        time.sleep(0.1)
    raise ShareError(
        f"local share server did not start on 127.0.0.1:{port}; inspect {log_path} "
        "or choose TAILSCALE_SHARE_PORT"
    )


def ensure_ready(root: Path, port: int) -> str:
    with startup_lock(root):
        start_daemon(root, port)
        hostname, _ = tailscale_identity()
        ensure_serve(hostname, port)
    return hostname


def reject_unsafe_source(path: Path) -> None:
    resolved = path.resolve()
    if not path.exists():
        raise ShareError(f"source does not exist: {path}")
    if path.is_symlink():
        raise ShareError(f"refusing to publish a symlink: {path}")
    if resolved == Path(resolved.anchor) or resolved == Path.home().resolve():
        raise ShareError(f"refusing to publish a broad system directory: {path}")
    if path.is_dir():
        for child in path.rglob("*"):
            if child.is_symlink():
                raise ShareError(f"refusing to publish a directory containing a symlink: {child}")


def new_share_id(destination_root: Path) -> str:
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    for _ in range(10):
        share_id = f"{stamp}-{secrets.token_hex(4)}"
        if not (destination_root / share_id).exists() and not (destination_root / f".tmp-{share_id}").exists():
            return share_id
    raise ShareError("could not allocate a unique share id")


def copy_source(source: Path, destination: Path) -> None:
    if source.is_dir():
        shutil.copytree(source, destination)
    elif source.is_file():
        shutil.copy2(source, destination)
    else:
        raise ShareError(f"source is not a regular file or directory: {source}")


def create_archive(archive: Path, items: Sequence[Path], *, include_parent: bool) -> None:
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for item in items:
            if item.is_dir():
                for child in sorted(item.rglob("*")):
                    if child.is_file():
                        base = item.parent if include_parent else item
                        bundle.write(child, child.relative_to(base))
            elif item.is_file():
                bundle.write(item, item.name)


def stage_publication(sources: Sequence[Path], root: Path) -> Dict[str, Any]:
    if not sources:
        raise ShareError("provide at least one file or directory")
    normalized = [source.expanduser().absolute() for source in sources]
    for source in normalized:
        reject_unsafe_source(source)
    names = [source.name for source in normalized]
    if len(names) != len(set(names)):
        raise ShareError("sources in one publication must have distinct basenames")

    public = content_root(root)
    meta = metadata_root(root)
    public.mkdir(parents=True, exist_ok=True)
    meta.mkdir(parents=True, exist_ok=True)
    share_id = new_share_id(public)
    temporary = public / f".tmp-{share_id}"
    destination = public / share_id
    temporary.mkdir()
    try:
        staged: List[Path] = []
        for source in normalized:
            target = temporary / source.name
            copy_source(source, target)
            staged.append(target)

        single = len(staged) == 1
        if single and staged[0].is_file():
            relative_view = quote(staged[0].name)
            relative_download = relative_view
        elif single:
            relative_view = quote(staged[0].name) + "/"
            relative_download = quote(staged[0].name + ".zip")
            create_archive(temporary / (staged[0].name + ".zip"), staged, include_parent=True)
        else:
            relative_view = ""
            relative_download = "download.zip"
            create_archive(temporary / "download.zip", staged, include_parent=True)

        os.replace(temporary, destination)
    except Exception:
        shutil.rmtree(temporary, ignore_errors=True)
        raise

    publication = {
        "id": share_id,
        "created_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "sources": [str(source) for source in normalized],
        "relative_view": relative_view,
        "relative_download": relative_download,
    }
    metadata_path = meta / f"{share_id}.json"
    metadata_path.write_text(json.dumps(publication, indent=2) + "\n", encoding="utf-8")
    return publication


def publication_urls(hostname: str, publication: Dict[str, Any]) -> Dict[str, Any]:
    base = f"https://{hostname}{MOUNT_PATH}/{publication['id']}/"
    result = dict(publication)
    result.update(
        {
            "host": hostname,
            "url": base + publication["relative_view"],
            "download_url": base + publication["relative_download"],
        }
    )
    return result


def share_id_from_reference(reference: str) -> str:
    if ID_RE.fullmatch(reference):
        return reference
    parsed = urlparse(reference)
    parts = [unquote(part) for part in parsed.path.split("/") if part]
    try:
        mount_index = parts.index(MOUNT_PATH.lstrip("/"))
        share_id = parts[mount_index + 1]
    except (ValueError, IndexError) as exc:
        raise ShareError(f"not a tailscale-share id or URL: {reference}") from exc
    if not ID_RE.fullmatch(share_id):
        raise ShareError(f"not a valid tailscale-share id: {share_id}")
    return share_id


def command_put(args: argparse.Namespace) -> int:
    root = data_root()
    port = configured_port()
    sources = [Path(value) for value in args.paths]
    for source in sources:
        reject_unsafe_source(source.expanduser().absolute())
    hostname = ensure_ready(root, port)
    publication = stage_publication(sources, root)
    result = publication_urls(hostname, publication)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(result["url"])
        if result["download_url"] != result["url"]:
            print(f"Download: {result['download_url']}", file=sys.stderr)
    return 0


def command_status(args: argparse.Namespace) -> int:
    root = data_root()
    port = configured_port()
    hostname: Optional[str] = None
    online = False
    mount: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    try:
        hostname, _ = tailscale_identity()
        online = True
        result = run(["tailscale", "serve", "status", "--json"])
        mount = find_mount(json.loads(result.stdout or "{}"), hostname)
    except (ShareError, json.JSONDecodeError) as exc:
        error = str(exc)
    result_payload = {
        "online": online,
        "host": hostname,
        "daemon": health(port),
        "port": port,
        "mount": MOUNT_PATH,
        "configured": mount is not None and str(mount.get("Proxy", "")).rstrip("/") == expected_proxy(port),
        "error": error,
    }
    if args.json:
        print(json.dumps(result_payload, indent=2))
    else:
        state = "ready" if result_payload["daemon"] and result_payload["configured"] else "not ready"
        print(f"share: {state}")
        print(f"host: {hostname or '-'}")
        print(f"local: http://127.0.0.1:{port}")
        if error:
            print(f"error: {error}", file=sys.stderr)
    return 0 if result_payload["daemon"] and result_payload["configured"] else 1


def command_get(args: argparse.Namespace) -> int:
    parsed = urlparse(args.url)
    if parsed.scheme != "https" or f"{MOUNT_PATH}/" not in parsed.path:
        raise ShareError(f"expected an https tailscale-share URL containing {MOUNT_PATH}/")
    name = Path(unquote(parsed.path.rstrip("/"))).name
    if args.url.endswith("/") or not name:
        raise ShareError("directory URLs are for browsing; use the publication's Download URL")
    destination = Path(args.output or name).expanduser()
    if destination.is_dir():
        destination = destination / name
    if destination.exists() and not args.force:
        raise ShareError(f"destination already exists: {destination}; use --force to overwrite")
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + f".tmp-{secrets.token_hex(4)}")
    try:
        request = Request(args.url, headers={"User-Agent": f"tailscale-share/{VERSION}"})
        with urlopen(request, timeout=30) as response, temporary.open("wb") as output:
            shutil.copyfileobj(response, output)
        os.replace(temporary, destination)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise
    print(destination)
    return 0


def command_remove(args: argparse.Namespace) -> int:
    root = data_root()
    share_id = share_id_from_reference(args.reference)
    publication = content_root(root) / share_id
    metadata = metadata_root(root) / f"{share_id}.json"
    if not publication.exists():
        raise ShareError(f"share not found: {share_id}")
    shutil.rmtree(publication)
    metadata.unlink(missing_ok=True)
    print(f"Removed staged copy {share_id}; original source files were not changed.")
    return 0


def command_daemon(args: argparse.Namespace) -> int:
    root = Path(args.root).expanduser()
    public = content_root(root)
    public.mkdir(parents=True, exist_ok=True)
    handler = functools.partial(ShareHandler, directory=str(public))
    try:
        with ShareServer(("127.0.0.1", args.port), handler) as server:
            (root / "server.pid").write_text(f"{os.getpid()}\n", encoding="ascii")
            server.serve_forever(poll_interval=0.5)
    except OSError as exc:
        raise ShareError(f"cannot bind 127.0.0.1:{args.port}: {exc}") from exc
    finally:
        (root / "server.pid").unlink(missing_ok=True)
    return 0


def parser() -> argparse.ArgumentParser:
    top = argparse.ArgumentParser(
        prog="share",
        description="Publish artifacts to your tailnet through a stable per-machine endpoint.",
        epilog="Common flow: share put screenshot.png; share get https://host.ts.net/.share/.../screenshot.png",
    )
    top.add_argument("--version", action="version", version=f"share {VERSION}")
    commands = top.add_subparsers(dest="command", required=True)

    put = commands.add_parser("put", help="publish files or directories")
    put.add_argument("paths", nargs="+", help="explicit files or directories to stage")
    put.add_argument("--json", action="store_true", help="print stable structured output")
    put.set_defaults(handler=command_put)

    get = commands.add_parser("get", help="download one published file or archive")
    get.add_argument("url", help="tailscale-share file or Download URL")
    get.add_argument("-o", "--output", help="destination file or existing directory")
    get.add_argument("-f", "--force", action="store_true", help="overwrite an existing destination")
    get.set_defaults(handler=command_get)

    status = commands.add_parser("status", help="check local Tailscale and share endpoint state")
    status.add_argument("--json", action="store_true", help="print stable structured output")
    status.set_defaults(handler=command_status)

    remove = commands.add_parser("remove", help="delete a staged share without touching its source")
    remove.add_argument("reference", help="share id or URL")
    remove.set_defaults(handler=command_remove)

    return top


def daemon_parser() -> argparse.ArgumentParser:
    internal = argparse.ArgumentParser(prog="share _daemon")
    internal.add_argument("--port", type=int, required=True)
    internal.add_argument("--root", required=True)
    return internal


def main(argv: Optional[Sequence[str]] = None) -> int:
    actual_argv = list(argv) if argv is not None else sys.argv[1:]
    if actual_argv and actual_argv[0] == "_daemon":
        args = daemon_parser().parse_args(actual_argv[1:])
        args.handler = command_daemon
    else:
        args = parser().parse_args(actual_argv)
    try:
        return int(args.handler(args))
    except ShareError as exc:
        print(f"share: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("share: interrupted", file=sys.stderr)
        return 130
    except (OSError, URLError) as exc:
        print(f"share: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
