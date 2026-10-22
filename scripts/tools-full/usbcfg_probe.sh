set +e
D=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.efi
ls -l "$D" | cat
OFF=$(grep -abo 'PMIC version' "$D" | head -1 | cut -d: -f1)
echo "string offset: $OFF"
python3 - "$D" "$OFF" <<'PY'
import sys, struct
p, off = sys.argv[1], int(sys.argv[2])
d = open(p,'rb').read()
print("near string:", d[off-40:off+60])
# locate CRC-like GUID constants mentioning nothing; just dump candidate .rodata GUIDs near
PY