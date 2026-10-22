set +e
python3 - <<'PY'
import pathlib
p = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/DXE.inc')
keep=[]
removed=[]
for ln in p.read_text(encoding='utf-8').splitlines(True):
    s=ln.strip()
    if s and ('UsbfnDwc3Dxe.inf' in s or 'UsbDeviceDxe.inf' in s or 'VermeerLogDiskDxe.inf' in s):
        removed.append(s); continue
    keep.append(ln)
p.write_text(''.join(keep), encoding='utf-8')
print('DXE.inc removed:', removed)
PY
grep -n 'UsbfnDwc3\|UsbDeviceDxe\|LogDisk' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/DXE.inc || echo "DXE.inc clean"