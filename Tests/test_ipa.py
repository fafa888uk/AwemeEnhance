"""Synthetic Mach-O fixtures only. These are NOT runnable Douyin applications."""
import io
import plistlib
import stat
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path
from tools import ipa, macho


def thin(filetype=2, encrypted=False, padding=4096, signature=False, dependencies=()):
    segment = bytearray(152)
    struct.pack_into("<II16sQQQQIIII", segment, 0, 0x19, 152, b"__TEXT", 0, 8192, 0, 8192, 7, 5, 1, 0)
    struct.pack_into("<16s16sQQIIIIIIII", segment, 72, b"__text", b"__TEXT", 0x1000, 4, padding, 2, 0, 0, 0x80000400, 0, 0, 0)
    cmds = [bytes(segment)]
    if encrypted:
        cmds.append(struct.pack("<6I", 0x2C, 24, padding, 4, 1, 0))
    if signature:
        cmds.append(struct.pack("<4I", macho.CODE_SIGNATURE, 16, 6000, 16))
    for dep in dependencies:
        name = dep.encode() + b"\0"
        size = (24 + len(name) + 7) & ~7
        cmds.append((struct.pack("<6I", macho.LOAD_DYLIB, size, 24, 0, 0, 0) + name).ljust(size, b"\0"))
    block = b"".join(cmds)
    head = struct.pack("<8I", 0xFEEDFACF, macho.ARM64, 0, filetype, len(cmds), len(block), 0, 0)
    data = bytearray((head + block).ljust(8192, b"\0"))
    data[padding:padding+4] = b"TEST"
    return bytes(data)


def fat(data):
    table = struct.pack(">II", 0xCAFEBABE, 1) + struct.pack(">IIIII", macho.ARM64, 0, 4096, len(data), 12)
    return table.ljust(4096, b"\0") + data


def fixture(path, data=None, version="41.3.0", bundle="com.ss.iphone.ugc.Aweme", extra=None):
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("Payload/Fixture.app/Info.plist", plistlib.dumps({"CFBundleIdentifier": bundle, "CFBundleShortVersionString": version, "CFBundleExecutable": "Fixture"}))
        archive.writestr("Payload/Fixture.app/Fixture", thin(signature=True) if data is None else data)
        archive.writestr("Payload/Fixture.app/_CodeSignature/CodeResources", b"synthetic")
        archive.writestr("iTunesMetadata.plist", b"not propagated")
        for name, value in (extra or {}).items():
            archive.writestr(name, value)


class MachOTests(unittest.TestCase):
    def test_inspect_arm64(self):
        self.assertEqual(macho.inspect(thin())[0]["cpu"], macho.ARM64)

    def test_inject_preserves_content(self):
        result = macho.inject(thin(), ipa.LOAD_PATH)
        self.assertEqual(result[4096:4100], b"TEST")
        self.assertEqual(macho.inspect(result)[0]["dependencies"][0]["path"], ipa.LOAD_PATH)

    def test_signature_removed(self):
        result = macho.remove_signatures(thin(signature=True))
        self.assertFalse(macho.inspect(result)[0]["signed"])
        self.assertEqual(result[4096:4100], b"TEST")

    def test_fat_injection(self):
        result = macho.inject(fat(thin()), ipa.LOAD_PATH)
        self.assertEqual(macho.inspect(result)[0]["dependencies"][0]["path"], ipa.LOAD_PATH)

    def test_encryption_rejected(self):
        with self.assertRaisesRegex(macho.MachOError, "encrypted"):
            macho.inject(thin(encrypted=True), ipa.LOAD_PATH)

    def test_no_padding_rejected(self):
        with self.assertRaises(macho.MachOError):
            macho.inject(thin(padding=184), ipa.LOAD_PATH)

    def test_duplicate_injection_rejected(self):
        with self.assertRaisesRegex(macho.MachOError, "already"):
            macho.inject(macho.inject(thin(), ipa.LOAD_PATH), ipa.LOAD_PATH)

    def test_bad_command_rejected(self):
        data = bytearray(thin()); struct.pack_into("<I", data, 36, 9)
        with self.assertRaises(macho.MachOError):
            macho.inspect(data)

    def test_truncation_rejected(self):
        for size in (0, 3, 5, 20, 40):
            with self.subTest(size=size), self.assertRaises(macho.MachOError):
                macho.inspect(thin()[:size])

    def test_invalid_fat_table_rejected(self):
        data = bytearray(fat(thin())); struct.pack_into(">I", data, 16, 0)
        with self.assertRaises(macho.MachOError):
            macho.inspect(data)

    def test_fat_cpu_mismatch_rejected(self):
        data = bytearray(fat(thin())); struct.pack_into(">I", data, 8, 7)
        with self.assertRaises(macho.MachOError):
            macho.inspect(data)

    def test_invalid_install_path_rejected(self):
        with self.assertRaises(macho.MachOError):
            macho.inject(thin(), "@executable_path/Frameworks/../outside.dylib")


class ArchiveTests(unittest.TestCase):
    def check_name(self, name):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            archive.writestr(name, b"test")
        data.seek(0)
        with zipfile.ZipFile(data) as archive:
            # Python on Windows normalizes backslashes during ZIP creation; model a hostile raw entry.
            archive.infolist()[0].filename = name
            ipa.validate_members(archive)

    def test_traversal_rejected(self):
        for name in ("../out", "/out", "Payload/../out", "C:/out", "Payload\\out", "Payload/./out"):
            with self.subTest(name=name), self.assertRaises(ipa.IPAError):
                self.check_name(name)

    def test_case_collision_rejected(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            archive.writestr("Payload/a", b"a"); archive.writestr("Payload/A", b"b")
        data.seek(0)
        with zipfile.ZipFile(data) as archive, self.assertRaises(ipa.IPAError):
            ipa.validate_members(archive)

    def test_symlink_rejected(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            info = zipfile.ZipInfo("Payload/link"); info.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(info, b"../outside")
        data.seek(0)
        with zipfile.ZipFile(data) as archive, self.assertRaises(ipa.IPAError):
            ipa.validate_members(archive)

    def test_regular_member(self):
        self.check_name("Payload/A.app/Info.plist")


class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.source, self.plugin, self.output = root/"source.ipa", root/"AwemeEnhance.dylib", root/"AwemeEnhance_41.3.0.ipa"
        fixture(self.source); self.plugin.write_bytes(thin(filetype=6))

    def run_build(self, **kwargs):
        values = dict(source=self.source, dylib=self.plugin, output=self.output, version="41.3.0", expected_sha256=ipa.sha256(self.source), owns=True)
        values.update(kwargs)
        return ipa.integrate(**values)

    def test_complete_synthetic_pipeline(self):
        report = self.run_build()
        self.assertEqual(report["version"], "41.3.0")
        self.assertEqual(report["device_test"], "not performed")
        self.assertEqual(report["output_sha256"], ipa.sha256(self.output))
        with zipfile.ZipFile(self.output) as archive:
            self.assertIsNone(archive.testzip())
            self.assertIn("Payload/Fixture.app/Frameworks/AwemeEnhance.dylib", archive.namelist())
            self.assertNotIn("iTunesMetadata.plist", archive.namelist())
            self.assertFalse(any("_CodeSignature" in name for name in archive.namelist()))
            self.assertFalse(macho.inspect(archive.read("Payload/Fixture.app/Fixture"))[0]["signed"])

    def test_rights_required(self):
        with self.assertRaises(ipa.IPAError): self.run_build(owns=False)

    def test_hash_mismatch_rejected(self):
        with self.assertRaisesRegex(ipa.IPAError, "SHA256"): self.run_build(expected_sha256="0"*64)

    def test_existing_output_not_overwritten(self):
        self.output.write_bytes(b"important")
        with self.assertRaises(ipa.IPAError): self.run_build()
        self.assertEqual(self.output.read_bytes(), b"important")

    def test_source_not_overwritten(self):
        original = self.source.read_bytes()
        with self.assertRaises(ipa.IPAError): self.run_build(output=self.source)
        self.assertEqual(self.source.read_bytes(), original)

    def test_wrong_version_rejected(self):
        fixture(self.source, version="40.0.0")
        with self.assertRaisesRegex(ipa.IPAError, "version"): self.run_build()

    def test_wrong_app_rejected(self):
        fixture(self.source, bundle="com.example.other")
        with self.assertRaisesRegex(ipa.IPAError, "identifier"): self.run_build()

    def test_encrypted_app_rejected(self):
        fixture(self.source, data=thin(encrypted=True))
        with self.assertRaisesRegex(ipa.IPAError, "encrypted"): self.run_build()

    def test_wrong_plugin_filetype_rejected(self):
        self.plugin.write_bytes(thin(filetype=2))
        with self.assertRaisesRegex(ipa.IPAError, "dynamic library"): self.run_build()

    def test_plugin_external_dependency_rejected(self):
        self.plugin.write_bytes(thin(filetype=6, dependencies=("/var/jb/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",)))
        with self.assertRaisesRegex(ipa.IPAError, "non-system"): self.run_build()

    def test_missing_host_dependency_rejected(self):
        fixture(self.source, data=thin(dependencies=("@rpath/Missing.framework/Missing",)))
        with self.assertRaisesRegex(ipa.IPAError, "unresolved"): self.run_build()

    def test_existing_plugin_rejected(self):
        fixture(self.source, extra={"Payload/Fixture.app/Frameworks/AwemeEnhance.dylib": thin(filetype=6)})
        with self.assertRaisesRegex(ipa.IPAError, "already"): self.run_build()

    def test_plugin_architecture_mismatch_rejected(self):
        data = bytearray(thin(filetype=6)); struct.pack_into("<I", data, 8, 2); self.plugin.write_bytes(data)
        with self.assertRaisesRegex(ipa.IPAError, "architecture"): self.run_build()


if __name__ == "__main__":
    unittest.main()
