"""Authorized private S3 I/O through the user's AWS CLI credential chain. Never creates resources."""
from __future__ import annotations
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit


class StorageError(ValueError):
    pass


def parse_s3(uri):
    parsed = urlsplit(uri)
    if parsed.scheme != "s3" or not re.fullmatch(r"[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]", parsed.netloc) or not parsed.path.lstrip("/") or parsed.query or parsed.fragment:
        raise StorageError("expected a specific s3://bucket/key URI without query or credentials")
    if any(ord(c) < 32 for c in parsed.path) or ".." in parsed.path.split("/"):
        raise StorageError("invalid object key")
    return parsed.netloc, parsed.path.lstrip("/")


def aws(args):
    if not shutil.which("aws"):
        raise StorageError("AWS CLI is required; use your existing authorized AWS profile or OIDC role")
    env = dict(os.environ, AWS_PAGER="", AWS_CLI_AUTO_PROMPT="off")
    result = subprocess.run(["aws", *args], capture_output=True, env=env, check=False)
    if result.returncode:
        # Do not leak object keys, account IDs or credential-related diagnostics into public logs.
        raise StorageError("AWS operation failed; inspect private IAM/network configuration")
    return result.stdout


def check_private(bucket):
    raw = aws(["s3api", "get-public-access-block", "--bucket", bucket, "--output", "json"])
    try:
        config = json.loads(raw)["PublicAccessBlockConfiguration"]
    except (ValueError, KeyError) as error:
        raise StorageError("cannot verify bucket public-access protection") from error
    if not all(config.get(key) is True for key in ("BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets")):
        raise StorageError("all four S3 public-access blocks must already be enabled")


def transfer(operation, uri, file, acknowledge_existing_storage_cost=False):
    # S3 requests, storage and egress can cost money even with a free Actions runner.
    if not acknowledge_existing_storage_cost:
        raise StorageError("S3 may incur charges; no cloud operation performed without explicit cost authorization")
    bucket, key = parse_s3(uri)
    check_private(bucket)
    file = Path(file)
    if operation == "get":
        if file.exists():
            raise StorageError("refusing to overwrite local input")
        file.parent.mkdir(parents=True, exist_ok=True)
        try:
            aws(["s3api", "get-object", "--bucket", bucket, "--key", key, str(file)])
        except Exception:
            file.unlink(missing_ok=True)
            raise
        file.chmod(0o600)
    elif operation == "put":
        if not file.is_file():
            raise StorageError("private output file missing")
        # IAM should additionally enforce SSE and object-key prefixes; no public ACL is sent.
        aws(["s3", "cp", str(file), uri, "--sse", "AES256", "--only-show-errors", "--no-progress"])
    else:
        raise StorageError("unknown transfer operation")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("operation", choices=("get", "put"))
    p.add_argument("--uri-env", required=True, help="Environment variable containing a private S3 URI; not a URL logged on command line")
    p.add_argument("--file", type=Path, required=True)
    p.add_argument("--authorize-existing-storage-cost", action="store_true")
    a = p.parse_args()
    try:
        transfer(a.operation, os.environ.get(a.uri_env, ""), a.file, a.authorize_existing_storage_cost)
    except (StorageError, OSError) as error:
        print(str(error) if isinstance(error, StorageError) else "Private storage I/O failed", file=sys.stderr)
        return 1
    print("Authorized private storage operation completed; no resource was created.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
