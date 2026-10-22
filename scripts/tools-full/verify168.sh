#!/bin/bash
set -u
cd /mnt/d/本地项目-01/_tools || exit 1
echo "=== verify168 (keys168 vs keys167) ==="
python3 verify164.py keys168 keys167 || exit 1

FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
echo "=== marker strings in FVMAIN (utf16 / ascii) ==="
python3 - "$FV" <<'PY'
import sys
d = open(sys.argv[1],'rb').read()
need = ["[168] provider done", "[168] menu entered", "[168] init start", "[168] init done",
        "[168] dma done", "[168] phy ready", "[168] smmu bypass done", "[168] evt ring set",
        "[168] ep armed", "[168] ep0 armed", "[168] replug done", "[168] loop start",
        "[168] alive evts=", "[168] replug retry", "[168] setup bm=", "[168] devaddr",
        "[MENU168]", "MENU168"]
for s in need:
    u = d.count(s.encode('utf-16-le'))
    a = d.count(s.encode('ascii'))
    print("  %-26s utf16=%d ascii=%d" % (s, u, a))
for bad in ["CpuDeadLoop", "Usb168Clear"]:
    print("  (expect 0) %-14s utf16=%d" % (bad, d.count(bad.encode('utf-16-le'))))
PY
echo "=== DtbExtn provider EFI marker (ascii/utf16) ==="
DTB=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerDtbExtnDxe.efi
[ -s "$DTB" ] || DTB=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerDtbExtnDxe.efi' | head -1)
ls -l "$DTB"
python3 - "$DTB" <<'PY'
import sys
d = open(sys.argv[1],'rb').read()
s = "[168] provider done"
print("  provider done ascii:", d.count(s.encode()), " utf16:", d.count(s.encode('utf-16-le')),
      " file bytes:", len(d))
PY
echo "=== img/FD shas ==="
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys168.img \
          /mnt/d/本地项目-01/K70-UEFI-build/K70-keys168-CONSOLE-MARKERS.img \
          /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys168.fd
