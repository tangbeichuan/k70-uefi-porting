#!/usr/bin/env bash
set +e
XREF=/tmp/guid-keys140probe.xref
E=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi

echo "=== keys140 FV providers relevant to UsbConfigDxe depex ==="
for n in ChipInfo Smem PlatformInfo SPMIDxe UsbConfigDxe UsbInitDxe UsbfnDwc3 UsbMsd UsbPwrCtrl PmicDxe QcomCharger; do
  printf '%-16s ' "$n"
  grep -i "$n" "$XREF" | head -2 | tr '\n' '|'
  echo
done

echo
echo "=== PE sections of UsbConfigDxe.patched.efi ==="
llvm-readobj --sections "$E" 2>/dev/null | grep -E "Name:|VirtualAddress|RawDataOffset|RawDataSize" | head -40

echo
echo "=== GUID file offsets in UsbConfigDxe ==="
python3 - <<'PY'
import struct, pathlib
p = pathlib.Path("/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi")
data = p.read_bytes()
def gb(s):
    q=s.split('-')
    return struct.pack('<IHH',int(q[0],16),int(q[1],16),int(q[2],16))+bytes.fromhex(q[3]+q[4])
for name,val in [("EB97088E","EB97088E-CFDF-49C6-BE4B-D906A5B20E86"),
                 ("PmicVer4684800A","4684800A-2755-4EDC-B443-7F8CEB3239D3"),
                 ("SPMI_FA5F306B","FA5F306B-F47D-4AC4-A47D-882F8204EC30"),
                 ("ChipInfo_B0760469","B0760469-970C-487A-A4B5-28DB7B45CEF1"),
                 ("SMEM_F4E5C7D0","F4E5C7D0-D239-47CB-AACD-7F66EF763238"),
                 ("PlatformInfo_157A5C45","157A5C45-21B2-43C5-BA7C-822FEE5FE599")]:
    pat=gb(val); off=0
    while True:
        i=data.find(pat,off)
        if i<0: break
        print("  %-22s file offset 0x%x" % (name,i))
        off=i+1
PY
