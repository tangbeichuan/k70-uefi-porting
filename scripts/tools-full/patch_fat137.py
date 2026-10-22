"""keys137 gate: make sure the FAT-formatted log disk is what actually compiles.

Runs in the build chain right after patch_copy123.py + patch_extn136.py and
before the vendor module trimming, i.e. after the LogDisk driver has been copied
into the UEFI package.  It fails the build (instead of silently shipping the old
keys122 RAM disk) when:

  * the copied VermeerLogDiskDxe.c is not byte-identical to the canonical
    _tools/VermeerLogDiskDxe.c,
  * the FAT formatter / lazy-chain code is missing from that copy,
  * the BlockIO media parameters were changed (1 MiB, 512 B blocks, 2048 blocks),
  * vermeer.dsc lost the LogDisk component, or
  * APRIORI.inc lost the LogDisk INF or no longer inserts it before the menu
    (patch_usb126.py owns that insertion - losing it drops BlockIO to 0),
  * VermeerMenuDxe.c lost the "[UI] BlockIO devices: %d" display patch.
"""

import hashlib
import pathlib
import sys

PKG = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg")
TOOLS = pathlib.Path("/mnt/d/本地项目-01/_tools")

DRV_SRC = TOOLS / "VermeerLogDiskDxe.c"
DRV_INF = TOOLS / "VermeerLogDiskDxe.inf"
DRV_DST = PKG / "Drivers" / "VermeerLogDiskDxe" / "VermeerLogDiskDxe.c"
DRV_DST_INF = PKG / "Drivers" / "VermeerLogDiskDxe" / "VermeerLogDiskDxe.inf"
DSC = PKG / "vermeer.dsc"
APRIORI = PKG / "Include" / "APRIORI.inc"
MENU = PKG / "Drivers" / "VermeerMenuDxe" / "VermeerMenuDxe.c"

COMPONENT = "vermeerPkg/Drivers/VermeerLogDiskDxe/VermeerLogDiskDxe.inf"
INF_LINE = "INF " + COMPONENT
MENU_INF = "INF vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.inf"

FAIL = []


def need(cond, msg):
    if not cond:
        FAIL.append(msg)
    print(("  OK   " if cond else "  FAIL ") + msg)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


print("[fat137] verifying the FAT log-disk driver that will be compiled")

need(DRV_DST.is_file(), "%s exists" % DRV_DST)
need(DRV_DST_INF.is_file(), "%s exists" % DRV_DST_INF)
if not DRV_DST.is_file():
    print("[fat137] FAILED: driver missing from the package")
    sys.exit(1)

src = DRV_SRC.read_text(encoding="utf-8")
dst = DRV_DST.read_text(encoding="utf-8")
need(dst == src, "package copy identical to _tools/VermeerLogDiskDxe.c (sha256 %s)" % sha256(DRV_SRC)[:16])
need(DRV_DST_INF.read_text(encoding="utf-8") == DRV_INF.read_text(encoding="utf-8"),
     "package INF identical to _tools/VermeerLogDiskDxe.inf")

markers = [
    ('"[FAT16] volume ready, root entries=%d', "volume-ready banner"),
    ("FatComputeGeometry", "FAT geometry computation"),
    ("FatFormatVolume", "on-disk formatter"),
    ("FatWriteBootSector", "BPB/boot sector writer"),
    ("FatGrowFileChain", "lazy cluster-chain growth"),
    ("FatAppendLogLine", "append-a-line API"),
    ("FatSelfCheck", "read-back self check"),
    ('"BOOTLOG TXT"', "BOOTLOG.TXT directory entry"),
    ('"K70 LOGDISK"', "volume label entry"),
]
for marker, what in markers:
    need(marker in dst, "%s present (%s)" % (what, marker))

# BlockIO behaviour must not change: 1 MiB media, 512 B blocks, 2048 blocks.
need("LOGDISK_BYTES       (1024U * 1024U)" in dst, "media size still 1 MiB")
need("LOGDISK_BLOCK       512U" in dst, "block size still 512")
need("mMedia.BlockSize        = LOGDISK_BLOCK" in dst, "BlockIO.Media.BlockSize unchanged")
need("mMedia.LastBlock        = LOGDISK_BLOCKS - 1" in dst, "BlockIO.Media.LastBlock unchanged (2047)")
need("&gEfiBlockIoProtocolGuid" in dst, "BlockIO protocol still installed")
need("&gEfiDevicePathProtocolGuid" in dst, "DevicePath still installed (menu counts BlockIO handles)")

need(COMPONENT in DSC.read_text(encoding="utf-8"), "vermeer.dsc lists the LogDisk component")

apr = APRIORI.read_text(encoding="utf-8").splitlines()
need(any(ln.strip() == INF_LINE for ln in apr), "APRIORI.inc dispatches the LogDisk INF")
try:
    log_idx = [ln.strip() for ln in apr].index(INF_LINE)
    menu_idx = [ln.strip() for ln in apr].index(MENU_INF)
    need(log_idx < menu_idx, "LogDisk dispatched before the menu (log_idx=%d < menu_idx=%d)" % (log_idx, menu_idx))
except ValueError:
    need(False, "APRIORI.inc has both LogDisk and Menu entries")

need("BlockIO devices: %d" in MENU.read_text(encoding="utf-8"),
     'VermeerMenuDxe still prints "[UI] BlockIO devices: %d"')

if FAIL:
    print("[fat137] FAILED - %d check(s) failed, refusing to build" % len(FAIL))
    sys.exit(1)
print("[fat137] OK - FAT log disk v2 will be compiled (driver sha256 %s)" % sha256(DRV_SRC)[:16])
