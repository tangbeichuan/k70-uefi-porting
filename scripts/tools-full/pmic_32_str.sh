#!/bin/bash
# dump NUL-terminated ASCII strings at given file offsets in PmicDxeLa.efi
EFI=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi
for off in "$@"; do
  o=$((off))
  python3 - "$EFI" "$o" <<'PY'
import sys
data=open(sys.argv[1],'rb').read()
o=int(sys.argv[2])
end=data.find(b'\x00', o)
print("0x%x: %r" % (o, data[o:end][:120]))
PY
done
