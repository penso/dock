#!/usr/bin/env python3
"""Create a checksummed source archive and Arch recipe from this checkout."""
import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import tarfile

ROOT = Path(__file__).resolve().parents[1]


def generate(root, output, version, release=False):
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Version must be MAJOR.MINOR.PATCH")
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"dock-{version}.tar.gz"
    files = [root / name for name in ("LICENSE", "VERSION", "README.md", "install-omarchy.sh", "tools/package_arch.py")]
    for name in ("bin", "qml", "config", "packaging"):
        files.extend(path for path in (root / name).rglob("*")
                     if path.is_file() and not {"tests", "__pycache__"}.intersection(path.relative_to(root).parts)
                     and path.suffix not in (".pyc", ".pyo"))
    epoch = int(os.environ.get("SOURCE_DATE_EPOCH", "0"))
    with archive.open("wb") as raw, gzip.GzipFile(filename="", fileobj=raw, mode="wb", mtime=epoch) as compressed:
        with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as tar:
            for path in sorted(files):
                if path.is_symlink():
                    raise ValueError(f"Source archive does not follow symlinks: {path}")
                relative = path.relative_to(root).as_posix()
                info = tarfile.TarInfo(f"dock-{version}/{relative}")
                version_bytes = (version + "\n").encode() if relative == "VERSION" else None
                info.size = len(version_bytes) if version_bytes else path.stat().st_size
                info.mode = 0o755 if relative.startswith("bin/") or relative == "install-omarchy.sh" else 0o644
                info.mtime = epoch
                info.uid = info.gid = 0
                info.uname = info.gname = "root"
                with (io.BytesIO(version_bytes) if version_bytes else path.open("rb")) as content:
                    tar.addfile(info, content)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    source = ("$url/releases/download/v$pkgver/dock-$pkgver.tar.gz" if release else "dock-$pkgver.tar.gz")
    template = (root / "packaging/arch/PKGBUILD.in").read_text()
    (output / "PKGBUILD").write_text(template.replace("@VERSION@", version).replace("@SOURCE@", source).replace("@SHA256@", digest))
    metadata = output / ".omarchy"
    metadata.mkdir(exist_ok=True)
    (metadata / "package.json").write_text(json.dumps(json.loads((root / "packaging/arch/package.json").read_text()), indent=2) + "\n")
    (output / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n")
    return archive


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist/arch")
    parser.add_argument("--version", default=(ROOT / "VERSION").read_text().strip())
    parser.add_argument("--release", action="store_true", help="Use the corresponding GitHub Release asset URL in PKGBUILD")
    args = parser.parse_args()
    print(generate(ROOT, args.output, args.version, args.release))


if __name__ == "__main__":
    main()
