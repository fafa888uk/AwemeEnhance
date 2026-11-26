"""Strict allow-list of publicly distributable, original plugin release files."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path
try:
    from .macho import inspect, ARM64
except ImportError:
    from macho import inspect, ARM64

ALLOWED = {"AwemeEnhance.dylib", "AwemeEnhance.deb", "SHA256SUMS.txt", "CHANGELOG.md", "BUILD-METADATA.json"}


def verify(directory=Path("dist")):
    if {p.name for p in directory.iterdir()} != ALLOWED or not all(p.is_file() for p in directory.iterdir()):
        raise ValueError("release must contain exactly the original artifact allow-list")
    dylib = inspect((directory/"AwemeEnhance.dylib").read_bytes())
    if any(e["cpu"] != ARM64 or e["filetype"] != 6 or e["encrypted"] for e in dylib):
        raise ValueError("invalid dylib architecture/type")
    for entry in dylib:
        if any(not d["path"].startswith(("/System/Library/", "/usr/lib/")) for d in entry["dependencies"]):
            raise ValueError("non-system dependency in standalone plugin")
    for line in (directory/"SHA256SUMS.txt").read_text().splitlines():
        digest, name = line.split("  ", 1)
        if name not in ALLOWED - {"SHA256SUMS.txt"} or not re.fullmatch(r"[a-f0-9]{64}", digest) or hashlib.sha256((directory/name).read_bytes()).hexdigest() != digest:
            raise ValueError("artifact checksum mismatch")
    listed = {line.split("  ", 1)[1] for line in (directory/"SHA256SUMS.txt").read_text().splitlines()}
    if listed != ALLOWED - {"SHA256SUMS.txt"}: raise ValueError("checksum coverage incomplete")
    print("Original plugin release allow-list and SHA256 checks passed.")


def collect():
    root = Path("dist")
    shutil.copyfile("CHANGELOG.md", root/"CHANGELOG.md")
    version = Path("VERSION").read_text().strip()
    ref = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    metadata = {"version": version, "commit": ref, "theos": json.loads(Path("dependencies.lock.json").read_text())["theos"]["sha"], "sdk": subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-version"], text=True).strip(), "device_validated": False, "compatibility": "experimental; 41.2.0/41.3.0 unverified"}
    (root/"BUILD-METADATA.json").write_text(json.dumps(metadata, indent=2)+"\n")
    lines = [f"{hashlib.sha256((root/name).read_bytes()).hexdigest()}  {name}" for name in sorted(ALLOWED - {"SHA256SUMS.txt"})]
    (root/"SHA256SUMS.txt").write_text("\n".join(lines)+"\n")


if __name__ == "__main__":
    p=argparse.ArgumentParser();p.add_argument("--collect",action="store_true");p.add_argument("--verify",action="store_true");a=p.parse_args()
    if a.collect: collect()
    if a.verify: verify()
