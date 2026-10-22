set +e
python3 - <<'PY'
import pathlib
pkg = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg')
usb = ['UsbfnDwc3Dxe/UsbfnDwc3Dxe.inf', 'UsbDeviceDxe/UsbDeviceDxe.inf']
for name in ('Include/APRIORI.inc', 'Include/DXE.inc'):
    p = pkg / name
    if not p.exists():
        continue
    out = []
    for ln in p.read_text(encoding='utf-8').splitlines(True):
        s = ln.strip()
        if any(u in s for u in usb) and not s.startswith('#'):
            out.append('# [keys123] ' + s + '\n')
            continue
        out.append(ln)
    p.write_text(''.join(out), encoding='utf-8')
    print(name, 'usb device lines commented again')
PY
grep -n 'UsbfnDwc3\|UsbDeviceDxe\|LogDisk\|VermeerMenuDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc | tail -6