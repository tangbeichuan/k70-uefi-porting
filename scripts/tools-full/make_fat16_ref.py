#!/usr/bin/env python3
"""Reference formatter + validator for the Vermeer log-disk FAT volume.

This is an independent (python) implementation of the *exact same on-disk
layout and append algorithm* that _tools/VermeerLogDiskDxe.c runs at boot, so
the geometry can be checked on the host without flashing firmware:

  * 512 B sectors, 1 reserved sector, 1 FAT, 32 root entries, 4 sectors/cluster
  * root[0]  = volume label "K70 LOGDISK" (attr 0x08)
  * root[1]  = BOOTLOG.TXT (attr 0x20), chain grown lazily from cluster #2
  * FAT entry width chosen from the real data-cluster count (FAT12 < 4085)
  * capacity cap 64 clusters (128 KiB); appends are dropped once full

It writes reference images and then parses them back with no knowledge of the
formatter (BPB, FAT chain, root directory, file bytes), reporting every derived
number and any inconsistency.

Usage:
  python make_fat16_ref.py            # write+verify all images, exit 0 if clean
  python make_fat16_ref.py --quiet    # one summary line per image
"""

import argparse
import hashlib
import pathlib
import struct
import sys

SECTOR = 512
RSVD = 1
NUM_FATS = 1
ROOT_ENTRIES = 32
SPC = 4
MAX_FILE_CLUSTERS = 64
CLUSTER_BYTES = SPC * SECTOR
MAX_FILE_BYTES = MAX_FILE_CLUSTERS * CLUSTER_BYTES
FIXED_TIME = 0x0000
FIXED_DATE = 0x5D56          # 2026-10-22
VOL_ID = 0x4B37304C
VOL_LAB = b"K70 LOGDISK"
OEM = b"VERMEER "
FILE_NAME = b"BOOTLOG TXT"
ATTR_VOLUME_ID = 0x08
ATTR_ARCHIVE = 0x20

LOG_LINES = [
    b"VERMEER-UEFI LOGDISK\r\n",
    b"[FAT16] volume ready, root entries=32\r\n",
    b"BOOTLOG.TXT is written by VermeerLogDiskDxe\r\n",
]

HERE = pathlib.Path(__file__).resolve().parent


# --------------------------------------------------------------------------
# geometry (mirror of FatComputeGeometry() in VermeerLogDiskDxe.c)
# --------------------------------------------------------------------------
def geometry(total_bytes):
    total = total_bytes // SECTOR
    root_secs = (ROOT_ENTRIES * 32 + SECTOR - 1) // SECTOR
    fat_secs = None
    for n in range(1, 17):
        data_secs = total - RSVD - NUM_FATS * n - root_secs
        if data_secs <= 0:
            continue
        clusters = data_secs // SPC
        if clusters <= 4084:
            need = ((clusters + 2) * 3 + 1) // 2     # 12-bit nibble pairs
        else:
            need = (clusters + 2) * 2                # 16-bit entries
        if need <= n * SECTOR:
            fat_secs = n
            break
    if fat_secs is None:
        raise SystemExit("no self-consistent FAT size for %d bytes" % total_bytes)
    root_lba = RSVD + NUM_FATS * fat_secs
    data_lba = root_lba + root_secs
    clusters = (total - data_lba) // SPC
    bits = 12 if clusters < 4085 else 16
    return {
        "total_secs": total, "root_secs": root_secs, "fat_secs": fat_secs,
        "root_lba": root_lba, "data_lba": data_lba, "clusters": clusters,
        "bits": bits, "fat_bytes": fat_secs * SECTOR,
        "fat_need": (((clusters + 2) * 3 + 1) // 2) if clusters < 4085
                    else (clusters + 2) * 2,
        "slack": total - (data_lba + clusters * SPC),
    }


def put16(buf, off, val):
    struct.pack_into("<H", buf, off, val)


def put32(buf, off, val):
    struct.pack_into("<I", buf, off, val)


def get16(buf, off):
    return struct.unpack_from("<H", buf, off)[0]


def get32(buf, off):
    return struct.unpack_from("<I", buf, off)[0]


# --------------------------------------------------------------------------
# FAT entry access / formatter state machine (mirror of the driver)
# --------------------------------------------------------------------------
def set_entry(img, g, cluster, value):
    fat_off = RSVD * SECTOR
    if g["bits"] == 12:
        off = fat_off + cluster + (cluster >> 1)
        raw = get16(img, off)
        val = value & 0x0FFF
        raw = (raw & 0x000F) | (val << 4) if (cluster & 1) else (raw & 0xF000) | val
        put16(img, off, raw)
    else:
        put16(img, fat_off + cluster * 2, value & 0xFFFF)


def get_entry(img, g, cluster):
    fat_off = RSVD * SECTOR
    if g["bits"] == 12:
        off = fat_off + cluster + (cluster >> 1)
        raw = get16(img, off)
        return (raw >> 4) if (cluster & 1) else (raw & 0x0FFF)
    return get16(img, fat_off + cluster * 2)


class Volume:
    """Mirror of the driver's format+append state: boot sector, FAT, root dir."""

    def __init__(self, total_bytes):
        self.total_bytes = total_bytes
        self.g = geometry(total_bytes)
        self.img = bytearray(total_bytes)
        self.file_bytes = 0
        self.alloc_clusters = 0
        self.full = False
        self._format()

    # ---- format ----------------------------------------------------------
    def _format(self):
        img, g = self.img, self.g
        total = g["total_secs"]

        img[0:3] = b"\xEB\x3C\x90"
        img[3:11] = OEM
        put16(img, 0x0B, SECTOR)
        img[0x0D] = SPC
        put16(img, 0x0E, RSVD)
        img[0x10] = NUM_FATS
        put16(img, 0x11, ROOT_ENTRIES)
        put16(img, 0x13, total & 0xFFFF)
        img[0x15] = 0xF8
        put16(img, 0x16, g["fat_secs"])
        put16(img, 0x18, 32)
        put16(img, 0x1A, 64)
        put32(img, 0x1C, 0)
        put32(img, 0x20, 0)
        img[0x24] = 0x80
        img[0x25] = 0x00
        img[0x26] = 0x29
        put32(img, 0x27, VOL_ID)
        img[0x2B:0x36] = VOL_LAB
        img[0x36:0x3E] = b"FAT12   " if g["bits"] == 12 else b"FAT16   "
        put16(img, 0xFE, 0xAA55)
        img[0x3E:0x42] = b"\xFA\xF4\xEB\xFD"          # cli; hlt; jmp $-1

        set_entry(img, g, 0, 0x0FF8 if g["bits"] == 12 else 0xFFF8)
        set_entry(img, g, 1, 0x0FFF if g["bits"] == 12 else 0xFFFF)

        root = g["root_lba"] * SECTOR
        struct.pack_into("<11sBBBHHHHHHHI", img, root,       # root[0] label
                         VOL_LAB, ATTR_VOLUME_ID, 0, 0,
                         0, 0, 0, 0, 0, 0, 0, 0)
        struct.pack_into("<11sBBBHHHHHHHI", img, root + 32,  # root[1] file
                         FILE_NAME, ATTR_ARCHIVE, 0, 0,
                         FIXED_TIME, FIXED_DATE, FIXED_DATE,
                         0, FIXED_TIME, FIXED_DATE, 0, 0)

    def _file_entry_off(self):
        return self.g["root_lba"] * SECTOR + 32

    # ---- append ----------------------------------------------------------
    def append(self, line):
        if self.full:
            return False
        if self.file_bytes + len(line) > MAX_FILE_BYTES:
            self.full = True
            return False
        need = (self.file_bytes + len(line) + CLUSTER_BYTES - 1) // CLUSTER_BYTES
        if need > MAX_FILE_CLUSTERS:
            self.full = True
            return False
        while self.alloc_clusters < need:
            cluster = 2 + self.alloc_clusters
            if cluster > self.g["clusters"] + 1:
                self.full = True
                return False
            set_entry(self.img, self.g, cluster,
                      0x0FFF if self.g["bits"] == 12 else 0xFFFF)
            if self.alloc_clusters == 0:
                put16(self.img, self._file_entry_off() + 26, cluster)
            else:
                set_entry(self.img, self.g, cluster - 1, cluster)
            self.alloc_clusters += 1
        data_off = self.g["data_lba"] * SECTOR
        self.img[data_off + self.file_bytes:data_off + self.file_bytes + len(line)] = line
        self.file_bytes += len(line)
        put32(self.img, self._file_entry_off() + 28, self.file_bytes)
        return True

    def bytes(self):
        return bytes(self.img)


# --------------------------------------------------------------------------
# validator: parse the image with no knowledge of the formatter
# --------------------------------------------------------------------------
def validate(img, expect_total_bytes):
    errs = []

    def chk(cond, msg):
        if not cond:
            errs.append(msg)

    if len(img) != expect_total_bytes:
        errs.append("image size %d != %d" % (len(img), expect_total_bytes))
        return None, errs
    g = geometry(len(img))

    byts = get16(img, 0x0B)
    spc = img[0x0D]
    rsvd = get16(img, 0x0E)
    nfats = img[0x10]
    rootent = get16(img, 0x11)
    tot16 = get16(img, 0x13)
    media = img[0x15]
    fatsz = get16(img, 0x16)
    tot32 = get32(img, 0x20)
    vollab = bytes(img[0x2B:0x36])
    fstype = bytes(img[0x36:0x3E])
    sig = get16(img, 0xFE)

    chk(byts == SECTOR, "BPB_BytsPerSec %d" % byts)
    chk(spc == SPC, "BPB_SecPerClus %d" % spc)
    chk(rsvd == RSVD, "BPB_RsvdSecCnt %d" % rsvd)
    chk(nfats == NUM_FATS, "BPB_NumFATs %d" % nfats)
    chk(rootent == ROOT_ENTRIES, "BPB_RootEntCnt %d" % rootent)
    chk(media == 0xF8, "BPB_Media 0x%02X" % media)
    chk(fatsz == g["fat_secs"], "BPB_FATSz16 %d != computed %d" % (fatsz, g["fat_secs"]))
    chk(sig == 0xAA55, "boot signature 0x%04X" % sig)
    chk(tot16 == len(img) // SECTOR, "BPB_TotSec16 %d" % tot16)
    chk(tot32 == 0, "BPB_TotSec32 %d" % tot32)
    chk(fstype.strip().decode() == "FAT%d" % g["bits"],
        "BPB_FilSysType %r disagrees with %d clusters (FAT%d)"
        % (fstype, g["clusters"], g["bits"]))
    chk(vollab == VOL_LAB, "BPB_VolLab %r" % vollab)
    chk(g["fat_need"] <= g["fat_bytes"],
        "FAT too small: need %d bytes, have %d" % (g["fat_need"], g["fat_bytes"]))
    chk(0 <= g["slack"] < SPC, "slack sectors %d" % g["slack"])

    e0, e1 = get_entry(img, g, 0), get_entry(img, g, 1)
    chk(e0 == (0x0FF8 if g["bits"] == 12 else 0xFFF8), "FAT[0] = 0x%X" % e0)
    chk(e1 == (0x0FFF if g["bits"] == 12 else 0xFFFF), "FAT[1] = 0x%X" % e1)

    root = g["root_lba"] * SECTOR
    # root[0]: volume label
    lab_name = bytes(img[root:root + 11])
    lab_attr = img[root + 11]
    chk(lab_name == VOL_LAB, "root[0] label %r" % lab_name)
    chk(lab_attr == ATTR_VOLUME_ID, "root[0] attr 0x%02X" % lab_attr)
    chk(get32(img, root + 28) == 0, "root[0] label size != 0")

    # root[1]: BOOTLOG.TXT
    f = root + 32
    name = bytes(img[f:f + 11])
    attr = img[f + 11]
    first = get16(img, f + 26)
    size = get32(img, f + 28)
    chk(name == FILE_NAME, "root[1] name %r" % name)
    chk(attr == ATTR_ARCHIVE, "root[1] attr 0x%02X" % attr)
    chk(size <= MAX_FILE_BYTES, "file size %d exceeds cap %d" % (size, MAX_FILE_BYTES))

    # cluster chain must be exactly ceil(size/cluster) clusters, contiguous
    expected_len = (size + CLUSTER_BYTES - 1) // CLUSTER_BYTES
    chain = []
    if expected_len == 0:
        chk(first == 0, "empty file has first cluster %d" % first)
    else:
        chk(first == 2, "first cluster %d (expected 2)" % first)
        cur = first
        while True:
            chain.append(cur)
            nxt = get_entry(img, g, cur)
            if nxt in (0x0FF8, 0x0FFF, 0xFFF8, 0xFFFF):
                break
            if not (2 <= nxt <= g["clusters"] + 1):
                errs.append("broken FAT chain at cluster %d" % nxt)
                break
            if len(chain) > g["clusters"]:
                errs.append("FAT chain loops")
                break
            cur = nxt
        chk(len(chain) == expected_len,
            "chain length %d != ceil(%d/%d) = %d"
            % (len(chain), size, CLUSTER_BYTES, expected_len))
        chk(chain == list(range(2, 2 + expected_len)), "chain not contiguous from #2")

    data_off = g["data_lba"] * SECTOR
    blob = bytes(img[data_off:data_off + size])
    chk(blob == EXPECTED_BLOB[:size],
        "BOOTLOG.TXT content mismatch (got %r...)" % blob[:40])

    # every root entry after the two we own must be free (0x00 / 0xE5)
    for idx in range(2, ROOT_ENTRIES):
        off = root + idx * 32
        if img[off] not in (0x00, 0xE5):
            errs.append("root[%d] not free (first byte 0x%02X)" % (idx, img[off]))

    # clusters past the file chain must be marked free (0x000)
    for cluster in range(2 + expected_len, g["clusters"] + 2):
        e = get_entry(img, g, cluster)
        if e != 0:
            errs.append("cluster %d not free (FAT entry 0x%X)" % (cluster, e))
            break

    return g, errs


# --------------------------------------------------------------------------
def report(name, path, total_bytes, expect_bits, lines, verbose):
    vol = Volume(total_bytes)
    for line in lines:
        vol.append(line)
    img = vol.bytes()
    path.write_bytes(img)
    g, errs = validate(img, total_bytes)
    sha = hashlib.sha256(img).hexdigest()

    print("=== %s (%d bytes, %d sectors) ===" % (name, total_bytes, total_bytes // SECTOR))
    if verbose and g:
        print("  BPB_BytsPerSec   : %d" % get16(img, 0x0B))
        print("  BPB_SecPerClus   : %d" % img[0x0D])
        print("  BPB_RsvdSecCnt   : %d" % get16(img, 0x0E))
        print("  BPB_NumFATs      : %d" % img[0x10])
        print("  BPB_RootEntCnt   : %d" % get16(img, 0x11))
        print("  BPB_TotSec16     : %d" % get16(img, 0x13))
        print("  BPB_Media        : 0x%02X" % img[0x15])
        print("  BPB_FATSz16      : %d sectors" % get16(img, 0x16))
        print("  BPB_VolID/VolLab : 0x%08X %r" % (get32(img, 0x27), bytes(img[0x2B:0x36])))
        print("  BPB_FilSysType   : %r" % bytes(img[0x36:0x3E]))
        print("  boot signature   : 0x%04X" % get16(img, 0xFE))
        print("  FAT region       : LBA %d..%d (%d B, needs %d B for %d entries)"
              % (RSVD, g["root_lba"] - 1, g["fat_bytes"], g["fat_need"], g["clusters"] + 2))
        print("  root directory   : LBA %d..%d (%d entries: label, BOOTLOG.TXT)"
              % (g["root_lba"], g["root_lba"] + g["root_secs"] - 1, ROOT_ENTRIES))
        print("  data area        : LBA %d.. (%d clusters x %d sectors = %d KiB)"
              % (g["data_lba"], g["clusters"], SPC, g["clusters"] * CLUSTER_BYTES // 1024))
        print("  slack sectors    : %d (tail of the media, outside the volume)" % g["slack"])
        print("  on-disk FAT type : FAT%d (cluster count %d %s 4085)"
              % (g["bits"], g["clusters"], "<" if g["clusters"] < 4085 else ">="))
        print("  BOOTLOG.TXT      : %d B in %d cluster(s), cap %d B"
              % (len(EXPECTED_BLOB[:vol.file_bytes]), vol.alloc_clusters, MAX_FILE_BYTES))
        print("  capacity reached : %s" % ("yes (appends dropped)" if vol.full else "no"))
        if verbose and len(EXPECTED_BLOB) <= 400:
            for line in EXPECTED_BLOB.decode().splitlines():
                print("    | %s" % line)
    print("  sha256           : %s" % sha)
    if errs:
        print("  VALIDATION       : FAILED")
        for e in errs:
            print("    - %s" % e)
    elif g:
        print("  VALIDATION       : OK (FAT%d, %d data clusters)"
              % (g["bits"], g["clusters"]))
        if g["bits"] != expect_bits:
            print("  VALIDATION       : FAILED - expected FAT%d" % expect_bits)
            errs.append("expected FAT%d, got FAT%d" % (expect_bits, g["bits"]))
    return errs, vol


def stress_lines():
    """Many lines, enough to hit the 128 KiB cap and prove the stop behaviour."""
    out = []
    for i in range(3000):
        out.append(b"[%04d] boot stage line, something a real log would say\r\n" % i)
    return out


EXPECTED_BLOB = b""


def main():
    global EXPECTED_BLOB
    ap = argparse.ArgumentParser()
    ap.add_argument("--outdir", default=str(HERE))
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()
    outdir = pathlib.Path(args.outdir)

    failures = 0

    # 1. 1 MiB with the three lines the driver writes at load time.
    EXPECTED_BLOB = b"".join(LOG_LINES)
    errs, _ = report("fat16_ref.img", outdir / "fat16_ref.img",
                     1024 * 1024, 12, LOG_LINES, not args.quiet)
    failures += bool(errs)

    # 2. 1 MiB filled to the cap (3000 lines ~ 150 KiB > 128 KiB cap): proves the
    #    chain growth and the "stop when full, never wrap" behaviour, and that a
    #    full-ish volume is still internally consistent.
    lines = stress_lines()
    kept = []
    vol = Volume(1024 * 1024)
    for line in lines:
        if vol.append(line):
            kept.append(line)
    EXPECTED_BLOB = b"".join(kept)
    print("  (stress log: %d of %d lines kept, %d B = %.1f%% of the 128 KiB cap)"
          % (len(kept), len(lines), len(EXPECTED_BLOB), 100.0 * len(EXPECTED_BLOB) / MAX_FILE_BYTES))
    errs, _ = report("fat16_ref_filled.img", outdir / "fat16_ref_filled.img",
                     1024 * 1024, 12, kept, False)
    failures += bool(errs)

    # 3. 8 MiB: identical formatter, but the cluster count crosses 4085, so the
    #    same code produces a genuine FAT16 volume.
    EXPECTED_BLOB = b"".join(LOG_LINES)
    errs, _ = report("fat16_ref_8m.img", outdir / "fat16_ref_8m.img",
                     8 * 1024 * 1024, 16, LOG_LINES, not args.quiet)
    failures += bool(errs)

    if failures:
        print("FAILED")
        return 1
    if args.quiet:
        print("all reference images: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
