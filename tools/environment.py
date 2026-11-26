import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path


def inspect():
    result = {"os": platform.system(), "python": platform.python_version(),
              "tools": {name: bool(shutil.which(name)) for name in ("git", "make", "clang", "xcodebuild", "xcrun", "dpkg-deb", "aws")},
              "theos_configured": bool(os.environ.get("THEOS"))}
    result["ios_sdk"] = False
    if result["os"] == "Darwin" and result["tools"]["xcrun"]:
        result["ios_sdk"] = subprocess.run(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], capture_output=True).returncode == 0
    root = Path(os.environ.get("THEOS", "__not_configured__"))
    result["theos_ready"] = (root / "makefiles/common.mk").is_file()
    return result


if __name__ == "__main__":
    p = argparse.ArgumentParser(); p.add_argument("--require-ios", action="store_true"); a = p.parse_args()
    result = inspect(); print(json.dumps(result, indent=2))
    if a.require_ios and not (result["os"] == "Darwin" and result["ios_sdk"] and result["theos_ready"] and all(result["tools"][n] for n in ("make", "clang", "dpkg-deb"))):
        print("iOS build unavailable in this environment; no binary was produced.", file=sys.stderr); raise SystemExit(1)
