"""Strict allow-list of publicly distributable, original plugin release files."""
import argparse
import hashlib
import json
import os
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


def publish():
    verify()
    tag=os.environ["RELEASE_TAG"]
    version=Path("VERSION").read_text().strip()
    if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+",tag) or tag[1:]!=version: raise ValueError("release version mismatch")
    repository=os.environ["GITHUB_REPOSITORY"]
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+",repository): raise ValueError("invalid repository")
    commit=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip()
    endpoint=f"repos/{repository}/git/ref/tags/{tag}"
    existing=subprocess.run(["gh","api",endpoint],capture_output=True,text=True)
    if existing.returncode:
        # Never interpret permission/network failure as a missing tag.
        if "HTTP 404" not in existing.stderr: raise RuntimeError("cannot verify existing release tag")
        subprocess.run(["gh","api",f"repos/{repository}/git/refs","-f","ref=refs/tags/"+tag,"-f","sha="+commit],check=True,stdout=subprocess.DEVNULL)
    else:
        obj=json.loads(existing.stdout)["object"]
        for _ in range(8):
            if obj["type"]!="tag": break
            obj=json.loads(subprocess.check_output(["gh","api",f"repos/{repository}/git/tags/{obj['sha']}"],text=True))["object"]
        if obj["type"]!="commit" or obj["sha"]!=commit: raise ValueError("existing tag does not match tested commit; refusing overwrite")
    subprocess.run(["gh","release","create",tag,"--verify-tag","--prerelease","--generate-notes","--notes-file","CHANGELOG.md",*[str(Path('dist')/name) for name in sorted(ALLOWED)]],check=True)


if __name__ == "__main__":
    p=argparse.ArgumentParser();p.add_argument("--collect",action="store_true");p.add_argument("--verify",action="store_true");p.add_argument("--publish",action="store_true");a=p.parse_args()
    if a.collect: collect()
    if a.verify: verify()
    if a.publish: publish()
