#!/bin/bash
set -u
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
FV=$B/FV/FVMAIN.Fv
echo "=== FVMAIN.Fv ==="
ls -l "$FV"
for s in 'GSNPSID=' '[VBUS] dec' 'phy_susphy' 'USBDIAG] DWC3[' 'DWC3 late run' 'probe end' 'run_stop='; do
  n=$(grep -ac -- "$s" "$FV" 2>/dev/null || true)
  echo "  [$s] = ${n:-0}"
done
echo "=== cf146d FD dump (head) ==="
head -40 /tmp/k148_fd.txt 2>/dev/null
echo "=== DTB sha of source ==="
sha256sum /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb
echo "=== DTB payload inside FVMAIN.Fv? ==="
python3 - <<'EOF'
import hashlib
fv = open('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv','rb').read()
src = open('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb','rb').read()
print("  fv size", len(fv), "src size", len(src))
print("  src sha256", hashlib.sha256(src).hexdigest())
i = fv.find(src)
print("  offset in FV:", hex(i) if i >= 0 else "NOT FOUND")
# count occurrences
c, p = 0, 0
while True:
    p = fv.find(src, p)
    if p < 0: break
    c += 1; p += 1
print("  occurrences:", c)
EOF
