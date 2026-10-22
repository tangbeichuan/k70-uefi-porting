import pathlib
pkg = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg")
usb = ["UsbfnDwc3Dxe/UsbfnDwc3Dxe.inf", "UsbDeviceDxe/UsbDeviceDxe.inf"]

# DXE.inc: keep them out (no duplicates)
dxe = pkg / "Include" / "DXE.inc"
out = []
for ln in dxe.read_text(encoding="utf-8").splitlines(True):
    s = ln.strip()
    if any(u.split("/")[0].lower() in s.lower() for u in usb) or "VermeerLogDiskDxe.inf" in s:
        continue
    out.append(ln)
dxe.write_text("".join(out), encoding="utf-8")

# APRIORI: uncomment the two usb device lines
apr = pkg / "Include" / "APRIORI.inc"
lines = apr.read_text(encoding="utf-8").splitlines(True)
out = []
enabled = 0
for ln in lines:
    s = ln.strip()
    hit = [u for u in usb if u in s]
    if hit:
        out.append("INF Binaries/vermeer/QcomPkg/Drivers/" + hit[0] + "\n")
        enabled += 1
        continue
    out.append(ln)
apr.write_text("".join(out), encoding="utf-8")
print("apriori usb device lines enabled:", enabled)