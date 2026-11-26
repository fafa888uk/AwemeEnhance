"""Private local IPA integration. Only original plugin artifacts may be public."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import plistlib
import re
import shutil
import stat
import sys
import tempfile
import zipfile
from pathlib import Path, PurePosixPath
try:
    from . import macho
except ImportError:
    import macho

LOAD_PATH = "@executable_path/Frameworks/AwemeEnhance.dylib"
MAX_EXPANDED = 12 * 1024**3
MAX_MEMBERS = 100000


class IPAError(ValueError):
    pass


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as file:
        for block in iter(lambda: file.read(1024**2), b""):
            h.update(block)
    return h.hexdigest()


def validate_members(archive):
    names, total = set(), 0
    members = archive.infolist()
    if len(members) > MAX_MEMBERS:
        raise IPAError("archive contains too many members")
    for info in members:
        name = info.filename
        if getattr(info, "orig_filename", name) != name or "\0" in getattr(info, "orig_filename", name):
            raise IPAError("ambiguous or NUL-truncated archive path")
        path = PurePosixPath(name)
        if not name or "\0" in name or "\\" in name or ":" in name or path.is_absolute() or any(p in ("", ".", "..") for p in name.rstrip("/").split("/")):
            raise IPAError("unsafe archive path")
        folded = name.rstrip("/").casefold()
        if folded in names:
            raise IPAError("duplicate or case-colliding archive path")
        names.add(folded)
        mode = info.external_attr >> 16
        if stat.S_ISLNK(mode) or (stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR)):
            raise IPAError("symlinks and special archive members are not supported")
        if info.flag_bits & 1:
            raise IPAError("encrypted ZIP members are not supported")
        total += info.file_size
        if total > MAX_EXPANDED or (info.file_size > 100 * 1024**2 and info.file_size > 1000 * max(1, info.compress_size)):
            raise IPAError("archive expansion limit exceeded")
    return members, total


def extract(archive, destination):
    members, total = validate_members(archive)
    if shutil.disk_usage(destination).free < total * 2 + 512 * 1024**2:
        raise IPAError("insufficient free space for safe integration")
    for info in members:
        if PurePosixPath(info.filename).parts[0] != "Payload":
            continue  # Do not propagate account-specific iTunes metadata.
        target = destination.joinpath(*PurePosixPath(info.filename).parts)
        if info.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with archive.open(info) as source, target.open("xb") as output:
            shutil.copyfileobj(source, output, 1024**2)  # CRC is verified by ZipExtFile.
        target.chmod((info.external_attr >> 16 & 0o777) or 0o644)


def app_info(root, version):
    apps = list((root / "Payload").glob("*.app"))
    if len(apps) != 1 or not apps[0].is_dir():
        raise IPAError("expected exactly one top-level application")
    app = apps[0]
    try:
        info = plistlib.loads((app / "Info.plist").read_bytes())
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        raise IPAError("missing or invalid app Info.plist") from error
    if info.get("CFBundleIdentifier") != "com.ss.iphone.ugc.Aweme":
        raise IPAError("bundle identifier is not the requested Douyin application")
    if info.get("CFBundleShortVersionString") != version or version not in ("41.2.0", "41.3.0"):
        raise IPAError("app version does not match the requested target")
    name = info.get("CFBundleExecutable")
    if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+", name) or name in (".", ".."):
        raise IPAError("unsafe or missing executable name")
    binary = app / name
    if not binary.is_file():
        raise IPAError("app executable is missing")
    return app, binary, info


def binaries(app):
    result = []
    for path in app.rglob("*"):
        if path.is_file():
            with path.open("rb") as file:
                magic = file.read(4)
            if macho.is_macho(magic):
                result.append(path)
    return result


def check_dependencies(app, binary, entries):
    """Resolve embedded and system libraries, but never execute untrusted app code."""
    warnings = []
    for entry in entries:
        paths = [app / "Frameworks", binary.parent / "Frameworks"]
        for path in entry["rpaths"]:
            if path.startswith("@executable_path/"):
                paths.append(app / path.removeprefix("@executable_path/"))
            elif path.startswith("@loader_path/"):
                paths.append(binary.parent / path.removeprefix("@loader_path/"))
        for dep in entry["dependencies"]:
            path = dep["path"]
            if path.startswith(("/System/Library/", "/usr/lib/")):
                continue
            if path.startswith("@executable_path/"):
                candidates = [app / path.removeprefix("@executable_path/")]
            elif path.startswith("@loader_path/"):
                candidates = [binary.parent / path.removeprefix("@loader_path/")]
            elif path.startswith("@rpath/"):
                candidates = [p / path.removeprefix("@rpath/") for p in paths]
            else:
                raise IPAError("non-system absolute or unsupported dylib dependency")
            exists = any(p.resolve().is_relative_to(app.resolve()) and p.is_file() for p in candidates)
            if not exists:
                if dep["weak"]:
                    warnings.append("unresolved weak dependency")
                else:
                    raise IPAError("unresolved embedded dylib dependency")
    return warnings


def inspect_tree(root, version):
    app, executable, info = app_info(root, version)
    files = binaries(app)
    if executable not in files:
        raise IPAError("main executable is not a supported Mach-O")
    warnings = []
    main = macho.inspect(executable.read_bytes())
    if any(e["cpu"] != macho.ARM64 or e["filetype"] != 2 for e in main):
        raise IPAError("main executable must contain only arm64 device slices")
    for path in files:
        entries = macho.inspect(path.read_bytes())
        if any(e["encrypted"] for e in entries):
            raise IPAError("encrypted Mach-O rejected; obtain an authorized modifiable input")
        warnings.extend(check_dependencies(app, path, entries))
    return app, executable, files, {
        "bundle_id": info["CFBundleIdentifier"], "version": version,
        "main_architectures": [{"cpu": e["cpu"], "subtype": e["subtype"]} for e in main],
        "macho_files_checked": len(files), "warnings": sorted(set(warnings)),
        "malware_scan": "not performed; structural checks do not establish safety or provenance",
        "device_test": "not performed", "signature": "not evaluated",
    }


def integrate(source, dylib, output, version, expected_sha256, owns=False):
    source, dylib, output = map(Path, (source, dylib, output))
    if not owns:
        raise IPAError("explicit modification-rights acknowledgment required")
    if output.suffix.lower() != ".ipa" or output.exists() or output.resolve() in (source.resolve(), dylib.resolve()):
        raise IPAError("output must be a new .ipa file; input overwrite is forbidden")
    if not re.fullmatch(r"[a-fA-F0-9]{64}", expected_sha256) or sha256(source) != expected_sha256.lower():
        raise IPAError("source SHA256 mismatch")
    plugin_data = dylib.read_bytes()
    plugin = macho.inspect(plugin_data)
    if any(e["cpu"] != macho.ARM64 or e["filetype"] != 6 or e["encrypted"] for e in plugin):
        raise IPAError("plugin must be an unencrypted arm64 dynamic library")
    for entry in plugin:
        if any(not d["path"].startswith(("/System/Library/", "/usr/lib/")) for d in entry["dependencies"]):
            raise IPAError("plugin has a non-system dependency; standalone injection is unsafe")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="aweme-private-", dir=output.parent) as temp:
        root = Path(temp)
        with zipfile.ZipFile(source) as archive:
            extract(archive, root)
        app, executable, files, report = inspect_tree(root, version)
        if (app / "Frameworks" / "AwemeEnhance.dylib").exists():
            raise IPAError("plugin already present")
        main_arches = {(e["cpu"], e["subtype"]) for e in macho.inspect(executable.read_bytes())}
        plugin_arches = {(e["cpu"], e["subtype"]) for e in plugin}
        if not main_arches <= plugin_arches:
            raise IPAError("plugin lacks a matching executable architecture/subtype")
        for path in files:
            path.write_bytes(macho.remove_signatures(path.read_bytes()))
        executable.write_bytes(macho.inject(executable.read_bytes(), LOAD_PATH))
        executable.chmod(0o755)
        target = app / "Frameworks" / "AwemeEnhance.dylib"
        target.parent.mkdir(exist_ok=True)
        target.write_bytes(macho.remove_signatures(plugin_data))
        target.chmod(0o755)
        # Remove invalidated bundle signatures and provisioning from ALL nested bundles.
        for path in sorted(app.rglob("_CodeSignature"), reverse=True):
            if path.is_dir():
                shutil.rmtree(path)
        for path in app.rglob("embedded.mobileprovision"):
            path.unlink()
        _, _, new_files, final = inspect_tree(root, version)
        if any(e["signed"] for path in new_files for e in macho.inspect(path.read_bytes())):
            raise IPAError("unexpected residual Mach-O signature")
        if not all(any(d["path"] == LOAD_PATH for d in e["dependencies"]) for e in macho.inspect(executable.read_bytes())):
            raise IPAError("plugin load command missing after integration")
        staged = root / "output.zip"
        with zipfile.ZipFile(staged, "w", zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as archive:
            for path in sorted((root / "Payload").rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(root).as_posix())
        # Verify serialization and CRC again, not only the staging directory.
        with zipfile.ZipFile(staged) as archive:
            validate_members(archive)
            if archive.testzip() is not None:
                raise IPAError("output archive CRC check failed")
        # Exclusive creation: never overwrite an existing private deliverable.
        created = False
        try:
            with output.open("xb") as file, staged.open("rb") as data:
                created = True
                shutil.copyfileobj(data, file, 1024**2)
        except Exception:
            if created and output.exists():
                output.unlink()
            raise
    report.update(final)
    report.update({"source_sha256": expected_sha256.lower(), "plugin_sha256": sha256(dylib),
                   "output_sha256": sha256(output), "signature": "unsigned; re-sign all nested code before installation",
                   "signing_readiness": "structural only; certificates, entitlements and device eligibility unverified"})
    report_path = output.with_suffix(".report.json")
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    output.with_name("SHA256SUMS.txt").write_text(f"{report['output_sha256']}  {output.name}\n{sha256(dylib)}  {dylib.name}\n", encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", type=Path, required=True)
    parser.add_argument("--dylib", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--version", choices=("41.2.0", "41.3.0"), default="41.3.0")
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--acknowledge-modification-rights", action="store_true")
    parser.add_argument("--inspect-only", action="store_true")
    args = parser.parse_args()
    try:
        if args.inspect_only:
            if sha256(args.ipa) != args.expected_sha256.lower():
                raise IPAError("source SHA256 mismatch")
            with tempfile.TemporaryDirectory(prefix="aweme-inspect-") as tmp:
                with zipfile.ZipFile(args.ipa) as archive:
                    extract(archive, Path(tmp))
                report = inspect_tree(Path(tmp), args.version)[3]
        else:
            if not args.dylib or not args.output:
                parser.error("--dylib and --output required for integration")
            report = integrate(args.ipa, args.dylib, args.output, args.version, args.expected_sha256, args.acknowledge_modification_rights)
        print(json.dumps(report, ensure_ascii=False, indent=2))
    except (IPAError, macho.MachOError, OSError, zipfile.BadZipFile) as error:
        # Paths or URLs are never echoed to public CI logs.
        print(f"IPA build failed: {type(error).__name__}: {error if isinstance(error, ValueError) else 'I/O or ZIP failure'}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
