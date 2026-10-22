set +e
D=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.efi
python3 - "$D" <<'PY'
import sys, uuid
d=open(sys.argv[1],'rb').read()
b=d[0x13178:0x13188]
u=uuid.UUID(bytes_le=b)
print("PMIC version proto GUID:", str(u).upper())
print("bytes:", b.hex())
PY