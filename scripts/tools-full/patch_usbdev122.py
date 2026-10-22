import pathlib

pkg = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg")
apr = pkg / "Include" / "APRIORI.inc"
a = apr.read_text(encoding="utf-8")
out = []
changed = []
for ln in a.splitlines(True):
    s = ln.strip()
    if s.startswith("#") and ("UsbfnDwc3Dxe.inf" in s or "UsbDeviceDxe.inf" in s):
        body = s.lstrip("#").strip()
        if body.startswith("["):
            body = body.split("]", 1)[1].strip()
        out.append(body + "\n")
        changed.append(body)
        continue
    out.append(ln)
apr.write_text("".join(out), encoding="utf-8")
print("uncommented:", changed)