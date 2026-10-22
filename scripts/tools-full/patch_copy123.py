import pathlib, shutil
pkg = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg")
src = pathlib.Path("/mnt/d/本地项目-01/_tools")
dst = pkg / "Drivers" / "VermeerLogDiskDxe"
dst.mkdir(parents=True, exist_ok=True)
for name in ("VermeerLogDiskDxe.c", "VermeerLogDiskDxe.inf"):
    shutil.copy2(src / name, dst / name)

dsc = pkg / "vermeer.dsc"
s = dsc.read_text(encoding="utf-8")
marker = "  vermeerPkg/Drivers/VermeerLogDiskDxe/VermeerLogDiskDxe.inf"
if marker not in s:
    idx = s.rfind("[Components]")
    end = s.find("\n[", idx + 10)
    if end < 0:
        end = len(s)
    s = s[:end] + marker + "\n" + s[end:]
    dsc.write_text(s, encoding="utf-8")
    print("dsc: logdisk component added")
else:
    print("dsc: logdisk component present")