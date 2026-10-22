import pathlib
apr = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc")
lines = apr.read_text(encoding="utf-8").splitlines(True)
want = ("UsbConfigDxe", "UsbInitDxe", "UsbMsdDxe", "UsbPwrCtrlDxe", "UsbDeviceDxe", "UsbfnDwc3Dxe")
out, enabled = [], []
for ln in lines:
    s = ln
    if s.lstrip().startswith("#") and any(w in s for w in want):
        # strip the comment prefix, keep INF line
        body = s.split("#", 1)[1].strip()
        if body.lower().startswith("inf "):
            s = body + "\n"
            enabled.append(body.split("/")[-1])
    out.append(s)
apr.write_text("".join(out), encoding="utf-8")
print("uncommented:", enabled)