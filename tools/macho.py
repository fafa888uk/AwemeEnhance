"""Conservative, original Mach-O inspection/editing. No decryption or signing bypass."""
from __future__ import annotations
import struct

ARM64 = 0x0100000C
LOAD_DYLIB = 0xC
WEAK_DYLIB = 0x80000018
REEXPORT_DYLIB = 0x8000001F
CODE_SIGNATURE = 0x1D
ENCRYPTION = (0x21, 0x2C)


class MachOError(ValueError):
    pass


def slices(data: bytes | bytearray):
    if len(data) < 4:
        raise MachOError("truncated Mach-O")
    if data[:4] == b"\xcf\xfa\xed\xfe":
        return [(0, len(data))]
    magic = bytes(data[:4])
    if magic not in (b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"):
        raise MachOError("only little-endian 64-bit Mach-O or big-endian FAT supported")
    if len(data) < 8:
        raise MachOError("truncated FAT header")
    count = struct.unpack_from(">I", data, 4)[0]
    stride = 32 if magic[-1] == 0xBF else 20
    if not 0 < count <= 32 or 8 + count * stride > len(data):
        raise MachOError("invalid FAT table")
    result = []
    for i in range(count):
        fmt = ">IIQQII" if stride == 32 else ">IIIII"
        fields = struct.unpack_from(fmt, data, 8 + i * stride)
        offset, size, align = fields[2:5]
        if align > 30 or offset % (1 << align) or size < 32 or offset < 8 + count * stride or offset + size > len(data):
            raise MachOError("invalid FAT slice range / alignment")
        if data[offset:offset + 4] != b"\xcf\xfa\xed\xfe":
            raise MachOError("unsupported FAT architecture format")
        if struct.unpack_from("<II", data, offset + 4) != fields[:2]:
            raise MachOError("FAT table and Mach-O CPU disagree")
        if any(offset < old + length and old < offset + size for old, length in result):
            raise MachOError("overlapping FAT slices")
        result.append((offset, size))
    return result


def commands(data, base, size):
    if size < 32 or base + size > len(data):
        raise MachOError("invalid Mach-O range")
    header = struct.unpack_from("<8I", data, base)
    count, length = header[4:6]
    if count > 10000 or 32 + length > size:
        raise MachOError("invalid load-command table")
    pos, end = base + 32, base + 32 + length
    result = []
    for _ in range(count):
        if pos + 8 > end:
            raise MachOError("truncated load command")
        cmd, n = struct.unpack_from("<II", data, pos)
        if n < 8 or n % 8 or pos + n > end:
            raise MachOError("invalid load command size")
        result.append((cmd, pos, n))
        pos += n
    if pos != end:
        raise MachOError("load command count / size mismatch")
    return header, result


def command_string(data, pos, size, minimum=12):
    if size < minimum:
        raise MachOError("short string load command")
    offset = struct.unpack_from("<I", data, pos + 8)[0]
    if offset < minimum or offset >= size:
        raise MachOError("invalid load-command string offset")
    text = bytes(data[pos + offset:pos + size])
    if b"\0" not in text:
        raise MachOError("unterminated load-command string")
    try:
        return text.split(b"\0", 1)[0].decode("utf-8")
    except UnicodeDecodeError as error:
        raise MachOError("invalid UTF-8 path") from error


def inspect(data: bytes | bytearray):
    result = []
    for base, size in slices(data):
        h, cmds = commands(data, base, size)
        entry = {"cpu": h[1], "subtype": h[2] & 0xFFFFFF, "filetype": h[3],
                 "encrypted": False, "signed": False, "dependencies": [], "rpaths": []}
        for cmd, pos, n in cmds:
            if cmd in ENCRYPTION:
                if n < 20:
                    raise MachOError("short encryption command")
                entry["encrypted"] |= struct.unpack_from("<I", data, pos + 16)[0] != 0
            if cmd == CODE_SIGNATURE:
                if n != 16:
                    raise MachOError("invalid signature command")
                off, length = struct.unpack_from("<II", data, pos + 8)
                if off + length > size:
                    raise MachOError("signature range outside file")
                entry["signed"] |= length > 0
            if cmd in (LOAD_DYLIB, WEAK_DYLIB, REEXPORT_DYLIB):
                entry["dependencies"].append({"path": command_string(data, pos, n, 24), "weak": cmd == WEAK_DYLIB})
            if cmd == 0x8000001C:
                entry["rpaths"].append(command_string(data, pos, n))
        result.append(entry)
    return result


def is_macho(data):
    # Detect unsupported variants too, so callers reject rather than silently skip them.
    return data[:4] in (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf",
                       b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf",
                       b"\xbe\xba\xfe\xca", b"\xbf\xba\xfe\xca")


def remove_signatures(data: bytes) -> bytes:
    result = bytearray(data)
    for base, size in slices(result):
        h, cmds = commands(result, base, size)
        kept = [bytes(result[p:p + n]) for c, p, n in cmds if c != CODE_SIGNATURE]
        block = b"".join(kept)
        result[base + 32:base + 32 + h[5]] = block + bytes(h[5] - len(block))
        struct.pack_into("<II", result, base + 16, len(kept), len(block))
    return bytes(result)


def inject(data: bytes, dependency: str) -> bytes:
    entries = inspect(data)
    if any(e["encrypted"] for e in entries):
        raise MachOError("encrypted input rejected; no decryption is implemented")
    if not dependency.startswith("@executable_path/Frameworks/") or ".." in dependency or "\0" in dependency:
        raise MachOError("invalid plugin install path")
    result = bytearray(remove_signatures(data))
    for base, size in slices(result):
        h, cmds = commands(result, base, size)
        if h[1] != ARM64 or h[3] != 2:
            raise MachOError("input must be an arm64 application executable")
        for c, p, n in cmds:
            if c in (LOAD_DYLIB, WEAK_DYLIB) and command_string(result, p, n, 24) == dependency:
                raise MachOError("plugin already injected")
        first_data = size
        found_section = False
        for c, p, n in cmds:
            if c != 0x19:
                continue
            if n < 72:
                raise MachOError("short segment command")
            sections = struct.unpack_from("<I", result, p + 64)[0]
            if n != 72 + 80 * sections:
                raise MachOError("invalid section table")
            for index in range(sections):
                q = p + 72 + 80 * index
                offset = struct.unpack_from("<I", result, q + 48)[0]
                length = struct.unpack_from("<Q", result, q + 40)[0]
                flags = struct.unpack_from("<I", result, q + 64)[0] & 0xFF
                if flags in (1, 0xC, 0x12):  # zero-fill sections have no bytes in this file
                    continue
                if offset and length:
                    if offset + length > size:
                        raise MachOError("section range outside slice")
                    found_section = True
                    first_data = min(first_data, offset)
        encoded = dependency.encode() + b"\0"
        length = (24 + len(encoded) + 7) & ~7
        start = 32 + h[5]
        if not found_section or start + length > first_data or any(result[base + start:base + start + length]):
            raise MachOError("insufficient zero header padding; refusing relocation")
        block = struct.pack("<6I", LOAD_DYLIB, length, 24, 0, 0, 0) + encoded
        result[base + start:base + start + length] = block.ljust(length, b"\0")
        struct.pack_into("<II", result, base + 16, h[4] + 1, h[5] + length)
    return bytes(result)
