set +e
U=/root/k70/uefi
grep -rnE 'PcdDebugPrintErrorLevel' "$U/Platforms/Xiaomi/vermeerPkg" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" "$U/Silicon/Qualcomm/QcomPkg/QcomPkg.dsc.inc" 2>/dev/null