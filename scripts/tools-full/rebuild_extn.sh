set +e
ls -l /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/ 2>/dev/null | grep -i vermeer
echo "--- flat efi remove + rebuild ---"
rm -f /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerDtbExtnDxe.efi
cd /root/k70/uefi
source /root/k70/venv/bin/activate 2>/dev/null
python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /tmp/b133c.log 2>&1
echo "exit=$?"
grep -iE 'error|VermeerDtbExtn' /tmp/b133c.log | head -8
ls -l /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerDtbExtnDxe.efi 2>/dev/null | cat