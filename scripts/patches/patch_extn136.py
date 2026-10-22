import pathlib, shutil
pkg = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg")
src = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe")
pd = pkg / "Drivers" / "VermeerDtbExtnDxe"
pd.mkdir(parents=True, exist_ok=True)
for n in ("VermeerDtbExtnDxe.c", "VermeerDtbExtnDxe.inf"):
    shutil.copy2(src / n, pd / n)
txt = (pd / "VermeerDtbExtnDxe.c").read_text(encoding="utf-8")
print("copied from port-drivers; 512 slots:", txt.count("A3, 512)"))

dsc = pkg / "vermeer.dsc"
s = dsc.read_text(encoding="utf-8")
need = "  vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.inf"
if need not in s:
    i = s.rfind("[Components]"); j = s.find("\n[", i + 10)
    if j < 0: j = len(s)
    dsc.write_text(s[:j] + need + "\n" + s[j:], encoding="utf-8")
    print("dsc: added")
else:
    print("dsc: present")

fdf = pkg / "vermeer.fdf"
f = fdf.read_text(encoding="utf-8")
i = f.find("!if $(VERMEER_KEYPROBE) == 1")
j = f.find("!endif", i)
inner = f[i:j]
add = ""
if "VermeerDtbExtnDxe" not in inner:
    add += "  INF vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.inf\n"
if "7E5B1C3A" not in inner:
    add += "FILE FREEFORM = 7E5B1C3A-9D24-4E77-9C1B-2A6D5F8E4C31 {\n  SECTION RAW = vermeerPkg/FdtBlob/xbl_ufs.dtb\n}\n"
if add:
    fdf.write_text(f[:j] + add + f[j:], encoding="utf-8")
    print("fdf: inserted")
else:
    print("fdf: present")

apr = pkg / "Include" / "APRIORI.inc"
lines = apr.read_text(encoding="utf-8").splitlines(True)
out, done = [], False
for ln in lines:
    if "VermeerDtbExtnDxe" in ln:
        continue
    out.append(ln)
    if (not done) and ("PCD/Dxe/Pcd.inf" in ln):
        out.append("INF vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.inf\n")
        done = True
apr.write_text("".join(out), encoding="utf-8")
print("apriori inserted:", done)