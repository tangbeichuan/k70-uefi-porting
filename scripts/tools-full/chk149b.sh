set +e
A=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64
echo "=== flat menu efi ==="
ls -l $A/VermeerMenuDxe.efi 2>/dev/null
strings $A/VermeerMenuDxe.efi 2>/dev/null | grep -c 'USB149'
echo "=== nested ==="
ls -l /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe/DEBUG/VermeerMenuDxe.efi 2>/dev/null
echo "=== in FVMAIN ==="
python3 - <<'PY'
import pathlib
fv = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv').read_bytes()
for s in (b'[USB149] pre', b'[USB149] run', b'[USB149] post'):
    print(s.decode(), '->', fv.find(s))
print('FVMAIN size', len(fv))
PY