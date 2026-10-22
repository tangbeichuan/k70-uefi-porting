set -u
# Does the banner module actually sit inside the FD?  Parse it the same way the delivery
# tooling does: FD -> FFS -> GUID_DEFINED(LZMA) section -> FVMAIN -> FFS -> UI section.
python3 - <<'PY'
import lzma, struct, uuid, sys

LZMA_GUID = 'ee4e5898-3914-4259-9d6e-dc7bd79403cf'

def u16(d, o): return struct.unpack_from('<H', d, o)[0]
def u24(d, o): return d[o] | d[o+1] << 8 | d[o+2] << 16
def u32(d, o): return struct.unpack_from('<I', d, o)[0]
def u64(d, o): return struct.unpack_from('<Q', d, o)[0]

def fv_header(d, base):
    assert d[base+base_sizecheck:] if False else True
    fvlen = u64(d, base+0x20)
    return fvlen

def walk_fv(d, base, end, out, depth=0):
    off = base + 0x38  # after FV header (single ext header)
    # find the FV header size from the extension header length field
    ext = u16(d, base+0x30 + 0x14 + 0x00) if False else None
    hdr_len = u16(d, base+0x30 + 0x12)
    off = base + hdr_len
    while off + 24 <= end:
        if d[off:off+16] == b'\xff' * 16:
            break
        name = d[off:off+16]
        typ = d[off+0x12]
        ffs_size = u24(d, off + 0x14)
        if ffs_size < 24:
            break
        body = off + 24
        if typ == 0x02:  # FREEFORM
            parse_sections(d, body, off + ffs_size, out, depth)
        elif typ in (0x03, 0x07, 0x0B, 0xF0, 0x01, 0x09):  # SEC/DXE/PEIM/FV_IMAGE/app/pad
            parse_sections(d, body, off + ffs_size, out, depth, fv_image=(typ == 0x0B))
        off = (off + ffs_size + 7) & ~7
    return out

def parse_sections(d, o, end, out, depth, fv_image=False):
    while o + 4 <= end:
        size = u24(d, o)
        styp = d[o + 3]
        if size == 0xFFFFFF or size < 4:
            return
        b = o + 4
        if styp == 0x15:  # UI
            out.append(('UI', d[b:o+size].decode('utf-16-le', 'replace').rstrip('\x00')))
        elif styp == 0x02:  # GUID_DEFINED
            g = str(uuid.UUID(bytes_le=d[b:b+16]))
            doff = u16(d, b + 16)
            if g == LZMA_GUID:
                raw = d[b + doff:o+size]
                try:
                    dec = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(raw)
                except Exception as e:
                    out.append(('LZMA_ERROR', str(e)))
                    dec = None
                if dec:
                    out.append(('LZMA_OK', len(dec)))
                    walk_fv(dec, 0, len(dec), out, depth + 1)
        elif styp == 0x19:  # RAW
            pass
        elif styp == 0x12:  # TE
            out.append(('TE', size))
        elif styp == 0x17:  # FV_IMAGE
            inner = b
            try:
                walk_fv(d, inner - 0x38 + 0x38, o + size, out, depth + 1)
            except Exception:
                pass
        o = (o + size + 3) & ~3

for path in sys.argv[1:] or ['/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-banner-qemu.fd']:
    d = open(path, 'rb').read()
    out = []
    walk_fv(d, 0, len(d), out)
    uis = [v for k, v in out if k == 'UI']
    print(path.split('/')[-1], 'size', len(d))
    print('  UI names:', len(uis))
    for n in uis:
        if 'Vermeer' in n or 'SimpleFb' in n or 'Bds' in n or 'GraphicsConsole' in n:
            print('   *', n)
    print('  LZMA entries:', [v for k, v in out if k == 'LZMA_OK'])
    print('  banner present:', any('VermeerBanner' in n for n in uis))
PY
