#!/usr/bin/env bash
set +e
cd /root/k70/uefi || exit 1
echo "=== EnvDxe referenced in vermeerPkg? ==="
grep -rn "EnvDxe" Platforms/Xiaomi/vermeerPkg/ | head -5
echo
echo "=== EnvDxe binary dir ==="
ls -l Binaries/vermeer/QcomPkg/Drivers/EnvDxe/ 2>/dev/null || echo "(no EnvDxe dir)"
echo
echo "=== vermeer.dsc vendor gate / defines ==="
grep -n "VERMEER_" Platforms/Xiaomi/vermeerPkg/vermeer.dsc | head -20
echo
echo "=== Clock / Display / RamManager mentions ==="
grep -n "ClockDxe\|DisplayDxe\|RamManagerDxe" Platforms/Xiaomi/vermeerPkg/vermeer.dsc Platforms/Xiaomi/vermeerPkg/vermeer.fdf | head -20
echo
echo "=== count of vendor INF refs in vermeer.dsc ==="
grep -c "Binaries/vermeer" Platforms/Xiaomi/vermeerPkg/vermeer.dsc
echo "=== count of vendor INF refs in vermeer.fdf ==="
grep -c "Binaries/vermeer" Platforms/Xiaomi/vermeerPkg/vermeer.fdf
