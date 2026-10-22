#!/usr/bin/env bash
# Pack both boot images from the SAME staged kernel, so the FV embedded in them is
# byte-identical to the published SILICIUM_UEFI.fd (rebuilding per variant would
# change the embedded build timestamp and break that guarantee).
set +e
cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate
OUT=/mnt/d/本地项目-01/K70-UEFI-build
K=Build/vermeerPkg/vermeer-kernel
FD=Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
echo "staged kernel: $(stat -c %s $K) bytes"
echo "FV           : $(stat -c %s $FD) bytes"

python3 Resources/Scripts/mkbootimg.py --kernel $K --ramdisk Resources/ramdisk \
    --header_version 1 -o /root/k70/Mu-vermeer.img || exit 1
python3 Resources/Scripts/mkbootimg.py --kernel $K --ramdisk Resources/ramdisk \
    --header_version 0 -o /root/k70/Mu-vermeer-hdr0.img || exit 1

cp -f $FD "$OUT/SILICIUM_UEFI.fd"
cp -f /root/k70/Mu-vermeer.img /root/k70/Mu-vermeer-hdr0.img "$OUT/"
cp -f Build/vermeerPkg/DEBUG_CLANGPDB/BUILD_REPORT.TXT "$OUT/BUILD_REPORT.TXT"
cp -f /root/k70/build-clean2.log "$OUT/BUILDLOG_vermeerPkg.txt"
cd "$OUT" && sha256sum *.fd *.img *.tar.gz *.TXT 2>/dev/null | grep -v vendorhw-DO-NOT-FLASH | sort -k2 > SHA256SUMS.txt
cat SHA256SUMS.txt
