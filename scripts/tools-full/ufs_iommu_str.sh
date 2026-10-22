set +e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi
ls -l $F
python3 - <<'PY'
import pathlib
p=pathlib.Path('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi')
b=p.read_bytes()
for needle in [b'IOMMU LocateProtocol failed', b'SMMU', b'UFS IOMMU']:
    i=b.find(needle)
    print(needle, '->', hex(i) if i>=0 else 'none')
    if i>=0:
        print('  ctx:', b[max(0,i-48):i+64])
PY