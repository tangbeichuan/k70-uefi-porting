set +e
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
ls -l --time-style=+%H:%M:%S $B/FV/SILICIUM_UEFI.fd $B/FV/FVMAIN_COMPACT.Fv 2>/dev/null
echo "--- Guid.xref mtime + SimpleFb ---"
ls -l --time-style=+%H:%M:%S $B/FV/Guid.xref
grep -c "" $B/FV/Guid.xref
echo "--- SimpleFb.efi ---"
find $B -name "SimpleFb*.efi" -newermt "-3 hours" 2>/dev/null | head -5
echo "--- MenuDxe ---"
find $B -name "VermeerMenuDxe.efi" 2>/dev/null | head -3