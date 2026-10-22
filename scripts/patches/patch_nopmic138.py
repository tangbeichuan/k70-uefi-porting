import pathlib
pkg = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg")
changed = []
for name in ("Include/APRIORI.inc", "Include/DXE.inc", "Include/RAW.inc"):
    p = pkg / name
    if not p.exists():
        continue
    lines = p.read_text(encoding="utf-8").splitlines(True)
    out, n = [], 0
    for ln in lines:
        s = ln.strip()
        if s.startswith("#"):
            out.append(ln); continue
        if "PmicDxeLa" in ln:
            out.append("# [keys138-nopmic] " + ln.lstrip()); n += 1; continue
        out.append(ln)
    if n:
        p.write_text("".join(out), encoding="utf-8")
        changed.append((name, n))
print("DROPPED", changed, flush=True)