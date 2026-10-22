import pathlib, re, shutil

SRC = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerUsbVbusDxe")
PKG = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg")
DST = PKG / "Drivers" / "VermeerUsbVbusDxe"
INF_REL = "vermeerPkg/Drivers/VermeerUsbVbusDxe/VermeerUsbVbusDxe.inf"
LINE = "INF " + INF_REL

DST.mkdir(parents=True, exist_ok=True)
for n in ("VermeerUsbVbusDxe.c", "VermeerUsbVbusDxe.inf"):
    shutil.copyfile(SRC / n, DST / n)

dsc = PKG / "vermeer.dsc"
s = dsc.read_text(encoding="utf-8", errors="surrogateescape")
if INF_REL not in s:
    m = re.search(r"^\[Components\]\s*$", s, re.M)
    assert m, "no [Components]"
    s = s[: m.end()] + "\n  " + INF_REL + "\n" + s[m.end():]
    dsc.write_text(s, encoding="utf-8", errors="surrogateescape")

ap = PKG / "Include" / "APRIORI.inc"
s = ap.read_text(encoding="utf-8", errors="surrogateescape")
lines = s.splitlines()
lines = [ln for ln in lines if "VermeerUsbVbusDxe" not in ln]   # drop stale
out = []
hit = False
for ln in lines:
    low = ln.lower()
    if (not hit) and ("usbfndwc3dxe.inf" in low or "usbdevicedxe.inf" in low
                      or "vermeerlogdiskdxe.inf" in low):
        out.append(LINE)
        hit = True
    out.append(ln)
if not hit:
    out.append(LINE)
ap.write_text("\n".join(out) + "\n", encoding="utf-8", errors="surrogateescape")
print("apriori inserted before usb-logdisk block:", hit)
idx = [i for i, l in enumerate(out) if "VermeerUsbVbusDxe" in l]
print("apriori line index:", idx, "of", len(out))