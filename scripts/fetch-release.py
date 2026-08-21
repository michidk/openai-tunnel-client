#!/usr/bin/env python3
"""Fetch and verify one official tunnel-client release archive."""

from __future__ import annotations

import argparse
import hashlib
import shutil
import stat
import time
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--arch", choices=("amd64", "arm64"), required=True)
    parser.add_argument("--sha256-amd64", required=True)
    parser.add_argument("--sha256-arm64", required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "michidk/openai-tunnel-client"},
    )
    for attempt in range(1, 6):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                with destination.open("wb") as archive:
                    shutil.copyfileobj(response, archive, 1024 * 1024)
            return
        except Exception:
            if attempt == 5:
                raise
            time.sleep(2 * attempt)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_extract(archive_path: Path, output: Path) -> None:
    required = {"tunnel-client", "cloudflared", "LICENSE", "NOTICE"}
    output.mkdir(parents=True, exist_ok=True)
    compliance = output / "compliance"
    compliance.mkdir()

    with zipfile.ZipFile(archive_path) as archive:
        names = {entry.filename for entry in archive.infolist() if not entry.is_dir()}
        missing = required - names
        if missing:
            raise SystemExit(f"release archive is missing: {', '.join(sorted(missing))}")

        for entry in archive.infolist():
            if entry.is_dir():
                continue
            archive_name = PurePosixPath(entry.filename)
            if archive_name.is_absolute() or ".." in archive_name.parts:
                raise SystemExit(f"unsafe archive path: {entry.filename}")
            if len(archive_name.parts) != 1:
                raise SystemExit(f"unexpected nested archive path: {entry.filename}")

            if entry.filename in {"tunnel-client", "cloudflared"}:
                destination = output / entry.filename
            else:
                destination = compliance / entry.filename
            with archive.open(entry) as source, destination.open("wb") as target:
                shutil.copyfileobj(source, target)
            destination.chmod(
                stat.S_IRUSR
                | stat.S_IWUSR
                | stat.S_IRGRP
                | stat.S_IROTH
                | (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH if destination.parent == output else 0)
            )


def main() -> None:
    args = parse_args()
    if not args.version or any(character not in "0123456789." for character in args.version):
        raise SystemExit("version must contain only digits and dots")

    expected = args.sha256_amd64 if args.arch == "amd64" else args.sha256_arm64
    archive_name = f"tunnel-client-v{args.version}-linux-{args.arch}.zip"
    archive_path = Path("/tmp") / archive_name
    url = f"https://github.com/openai/tunnel-client/releases/download/v{args.version}/{archive_name}"
    download(url, archive_path)

    actual = sha256(archive_path)
    if actual != expected:
        raise SystemExit(f"checksum mismatch for {archive_name}: expected {expected}, got {actual}")

    safe_extract(archive_path, args.output)


if __name__ == "__main__":
    main()
