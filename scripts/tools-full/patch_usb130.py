import pathlib, re
apr = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc")
lines = apr.read_text(encoding="utf-8").splitlines(True)
want = ("UsbfnDwc3Dxe", "UsbDeviceDxe", "UsbConfigDxe", "UsbInitDxe", "UsbMsdDxe", "UsbPwrCtrlDxe")
out, changed = [], []
for ln in lines:
    s = ln
    st = s.strip()
    if st.startswith("#") and any(w in st for w in want):
        m = re.match(r'^#\s*(?:\[[^\]]*\]\s*)?(INF\s+\S+)\s*$', st)
        if m:
            s = "  " + m.group(1) + "\n"
            changed.append(m.group(1).split("/")[-1])
    out.append(s)
apr.write_text("".join(out), encoding="utf-8")
print("uncommented:", changed)