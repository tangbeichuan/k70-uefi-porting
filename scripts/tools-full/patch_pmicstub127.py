import pathlib, shutil
pkg = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg")
src_dir = pkg / "Drivers" / "VermeerPmicVerStubDxe"
src_dir.mkdir(parents=True, exist_ok=True)
for f in ("VermeerPmicVerStubDxe.c", "VermeerPmicVerStubDxe.inf"):
    shutil.copy("/mnt/d/本地项目-01/_tools/" + f, src_dir / f)
    print("copied", f)

comp_line = "  vermeerPkg/Drivers/VermeerPmicVerStubDxe/VermeerPmicVerStubDxe.inf\n"
dsc = pkg / "vermeer.dsc"
txt = dsc.read_text(encoding="utf-8")
if comp_line.strip() not in txt:
    marker = "[Components]"
    i = txt.index(marker) + len(marker)
    txt = txt[:i] + "\n" + comp_line + txt[i:]
    dsc.write_text(txt, encoding="utf-8")
    print("dsc: added")
else:
    print("dsc: present")

apr = pkg / "Include" / "APRIORI.inc"
lines = apr.read_text(encoding="utf-8").splitlines(True)
out, done = [], False
for ln in lines:
    s = ln.strip()
    if "VermeerPmicVerStubDxe" in s:
        continue
    if (not done) and ("UsbDeviceDxe" in s or "UsbConfigDxe" in s):
        out.append("INF vermeerPkg/Drivers/VermeerPmicVerStubDxe/VermeerPmicVerStubDxe.inf\n")
        done = True
    out.append(ln)
if not done:
    out.append("INF vermeerPkg/Drivers/VermeerPmicVerStubDxe/VermeerPmicVerStubDxe.inf\n")
apr.write_text("".join(out), encoding="utf-8")
print("apriori: inserted", done)