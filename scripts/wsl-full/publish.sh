#!/usr/bin/env bash
# Publish the build artifacts to the Windows workspace.
set +e
OUT=/mnt/d/本地项目-01/K70-UEFI-build
INC=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
mkdir -p "$OUT"

cp -f /root/k70/uefi/Mu-vermeer.img                                   "$OUT/Mu-vermeer.img"
cp -f "$INC/FV/SILICIUM_UEFI.fd"                                      "$OUT/SILICIUM_UEFI.fd"
cp -f "$INC/BUILD_REPORT.TXT"                                         "$OUT/BUILD_REPORT.TXT"
cp -f /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt                    "$OUT/BUILDLOG_vermeerPkg.txt"
cp -f /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc          "$OUT/vermeer.dsc"
cp -f /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf          "$OUT/vermeer.fdf"
cp -f /root/k70/uefi/Resources/Configs/vermeer.toml                   "$OUT/vermeer.toml"
cp -f /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c        "$OUT/MemoryMapLib.c"
cp -f /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/ConfigurationMapLib/ConfigurationMapLib.c "$OUT/ConfigurationMapLib.c"

cd "$OUT" || exit 1
sha256sum Mu-vermeer.img SILICIUM_UEFI.fd | tee SHA256SUMS.txt
ls -l
echo
echo "===== Display Reserved descriptor check (FrameBufferSerialPortLib looks this name up) ====="
grep -n 'Display Reserved' MemoryMapLib.c
