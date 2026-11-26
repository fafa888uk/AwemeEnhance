"""Repository safety invariants and optional OSV advisory query; not a full malware audit."""
import argparse
import ast
import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIRS = {"Sources", "Tests", "tools", "scripts", ".github", "docs", "licenses"}
ROOT_FILES = {".gitignore", ".gitattributes", "VERSION", "LICENSE", "Makefile", "control", "AwemeEnhance.plist", "README.md", "README.en.md", "CHANGELOG.md", "dependencies.lock.json", "requirements-dev.txt", "SECURITY.md", "CONTRIBUTING.md"}


def public_files():
    files = [ROOT/p for p in sorted(ROOT_FILES) if (ROOT/p).is_file()]
    for directory in sorted(DIRS):
        path = ROOT/directory
        if path.exists():
            files.extend(p for p in path.rglob("*") if p.is_file() and "__pycache__" not in p.parts)
    return sorted(files)


def audit():
    for file in public_files():
        if file.is_symlink() or file.suffix.lower() in {".ipa", ".dylib", ".deb", ".p12", ".pem", ".key", ".mobileprovision"}:
            raise ValueError("binary/private material in public source manifest")
        text = file.read_text(encoding="utf-8")
        if re.search(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", text):
            raise ValueError("private key in public source")
        if re.search(r"(?:ghp_|github_pat_)[A-Za-z0-9_]{25,}|AKIA[A-Z0-9]{16}", text):
            raise ValueError("potential credential in public source")
        if file.suffix == ".py": ast.parse(text, filename=str(file))
        if file.is_relative_to(ROOT/"Sources") and any(s in text for s in ("NSURLSession", "NSURLConnection", "WKWebView", "dlopen(", "system(", "popen(")):
            raise ValueError("runtime network/code-loading capability requires explicit security review")
    for file in (ROOT/".github/workflows").glob("*.yml"):
        text = file.read_text()
        for action in re.findall(r"uses:\s*([^\s#]+)", text):
            if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[a-f0-9]{40}", action):
                raise ValueError("Actions must use full commit pins")
        runners = re.findall(r"runs-on:\s*(\S+)", text)
        if any(r not in {"ubuntu-latest", "macos-latest"} for r in runners): raise ValueError("non-standard/paid runner")
        if file.name == "build-ipa.yml" and ("uses: actions/upload-artifact" in text or "uses: actions/cache" in text or "gh release" in text): raise ValueError("private IPA must not be publicly uploaded/cached")
    lock = json.loads((ROOT/"dependencies.lock.json").read_text())
    if not re.fullmatch(r"[a-f0-9]{40}", lock["theos"]["sha"]) or lock["runtime_dependencies"]: raise ValueError("unexpected unlocked runtime dependency")
    print(f"Public-source invariants passed ({len(public_files())} files); no runtime network dependency.")


def advisories():
    lock = json.loads((ROOT/"dependencies.lock.json").read_text())
    queries = [{"commit": lock["theos"]["sha"]}, {"package":{"name":"PyYAML","ecosystem":"PyPI"},"version":"6.0.3"}]
    request = urllib.request.Request("https://api.osv.dev/v1/querybatch", data=json.dumps({"queries":queries}).encode(), headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(request, timeout=30) as response: result=json.load(response)
    findings=[v["id"] for item in result["results"] for v in item.get("vulns",[])]
    if findings: raise ValueError("OSV advisories require review: "+", ".join(findings))
    print("OSV returned no matched advisories for the pinned Theos commit and dev-only PyYAML. Database coverage is not a security guarantee.")


if __name__ == "__main__":
    p=argparse.ArgumentParser();p.add_argument("--advisories",action="store_true");a=p.parse_args();audit()
    if a.advisories: advisories()
