set +e
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
echo "DCFD1E6D in FVMAIN.Fv.txt:"; grep -c "DCFD1E6D" $FV/FVMAIN.Fv.txt
echo "4F7A1C2E in FVMAIN.Fv.txt:"; grep -c "4F7A1C2E" $FV/FVMAIN.Fv.txt
echo "--- total lines:"; wc -l < $FV/FVMAIN.Fv.txt
echo "--- FVMAIN_COMPACT.Fv.txt head:"; head -8 $FV/FVMAIN_COMPACT.Fv.txt
echo "--- FD vs FVMAIN_COMPACT sizes ---"
stat -c "%n %s" $FV/SILICIUM_UEFI.fd $FV/FVMAIN_COMPACT.Fv
echo "--- fdf FV sections ---"; grep -n "^\[FV\|INF \|FILE " /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf | sed -n '1,12p'