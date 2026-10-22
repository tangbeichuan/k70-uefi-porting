set +e
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
echo "=== FVMAIN.Fv.txt: MenuDxe? ==="; grep -c "VermeerMenuDxe" $FV/FVMAIN.Fv.txt
echo "=== FVMAIN.Fv.txt: SimpleFb? ==="; grep -c "SimpleFb" $FV/FVMAIN.Fv.txt
echo "=== first 15 FFS entries ==="; head -30 $FV/FVMAIN.Fv.txt
echo "=== fdf around line 61-90 ==="; sed -n '55,95p' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf