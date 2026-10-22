set +e
F=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf
grep -n 'FvNameGuid\|FvLength\|BlockSize\|NumBlocks\|Size =\|\[FD\.\|\[FV\.' "$F" | head -40
echo "=== FVMAIN/FVMAIN_COMPACT lines with numbers ==="
grep -n 'FVMAIN' "$F" | head -20