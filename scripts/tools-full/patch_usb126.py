import pathlib
pkg = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg")
usb = ["UsbfnDwc3Dxe/UsbfnDwc3Dxe.inf", "UsbDeviceDxe/UsbDeviceDxe.inf"]
log_line = "INF vermeerPkg/Drivers/VermeerLogDiskDxe/VermeerLogDiskDxe.inf"
menu_line = "INF vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.inf"

# DXE.inc must not duplicate anything (APRIORI is inside FV already)
dxe = pkg / "Include" / "DXE.inc"
out = []
for ln in dxe.read_text(encoding="utf-8").splitlines(True):
    s = ln.strip()
    if "VermeerLogDiskDxe.inf" in s:
        continue
    if any(u.split('/')[0].lower() in s.lower() for u in usb):
        continue
    out.append(ln)
dxe.write_text("".join(out), encoding="utf-8")

# APRIORI: usb device lines enabled + logdisk right before menu
apr = pkg / "Include" / "APRIORI.inc"
out = []
for ln in apr.read_text(encoding="utf-8").splitlines(True):
    s = ln.strip()
    if "VermeerLogDiskDxe.inf" in s:
        continue
    if any(u.split('/')[0].lower() in s.lower() for u in usb):
        continue
    out.append(ln)

res = []
have_usb = 0
inserted = False
for ln in out:
    if s_has := (ln.strip() == menu_line):
        for u in usb:
            res.append("INF Binaries/vermeer/QcomPkg/Drivers/" + u + "\n")
            have_usb += 1
        res.append(log_line + "\n")
        inserted = True
    res.append(ln)
if not inserted:
    for u in usb:
        res.append("INF Binaries/vermeer/QcomPkg/Drivers/" + u + "\n")
    res.append(log_line + "\n")
apr.write_text("".join(res), encoding="utf-8")
print("usb lines:", have_usb, "logdisk before menu:", inserted)