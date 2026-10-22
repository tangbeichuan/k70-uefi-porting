import pathlib

pkg = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg")
usb_lines = [
    "INF Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.inf",
    "INF Binaries/vermeer/QcomPkg/Drivers/UsbDeviceDxe/UsbDeviceDxe.inf",
]
log_line = "INF vermeerPkg/Drivers/VermeerLogDiskDxe/VermeerLogDiskDxe.inf"
menu_line = "INF vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.inf"

# ---- restore DXE.inc to its original (usb device lines commented, no logdisk) ----
dxe = pkg / "Include" / "DXE.inc"
out = []
for ln in dxe.read_text(encoding="utf-8").splitlines(True):
    s = ln.strip()
    if "VermeerLogDiskDxe.inf" in s:
        continue                      # never keep our own driver here
    if ("UsbfnDwc3Dxe.inf" in s or "UsbDeviceDxe.inf" in s) and not s.startswith("#"):
        out.append("# " + s + "\n")   # keep them out of the FV for now
        continue
    out.append(ln)
dxe.write_text("".join(out), encoding="utf-8")
print("DXE.inc sanitised")

# ---- APRIORI: logdisk before menu ----
apr = pkg / "Include" / "APRIORI.inc"
lines = []
for ln in apr.read_text(encoding="utf-8").splitlines(True):
    s = ln.strip()
    if "VermeerLogDiskDxe.inf" in s:
        continue
    if ("UsbfnDwc3Dxe.inf" in s or "UsbDeviceDxe.inf" in s) and not s.startswith("#"):
        lines.append("# " + s + "\n")
        continue
    lines.append(ln)

res = []
inserted = False
for ln in lines:
    if (not inserted) and ln.strip() == menu_line:
        res.append(log_line + "\n")
        inserted = True
    res.append(ln)
if not inserted:
    res.append(log_line + "\n")
apr.write_text("".join(res), encoding="utf-8")
print("APRIORI: logdisk before menu =", inserted)