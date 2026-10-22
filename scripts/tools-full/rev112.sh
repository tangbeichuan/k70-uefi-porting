set +e
G=/mnt/d/本地项目-01/_k70port_extract/wsl/gates.py
python3 - "$G" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
# make gop() a no-op: locating the def and injecting an early return
marker = "def gop(dsc: pathlib.Path, fdf: pathlib.Path) -> None:"
if marker in s and "def gop(dsc: pathlib.Path, fdf: pathlib.Path) -> None:\n    return  # keys112: SimpleFbDxe already comes from Include/DXE.inc" not in s:
    s = s.replace(marker, marker + "\n    return  # keys112: SimpleFbDxe already comes from Include/DXE.inc", 1)
    p.write_text(s, encoding='utf-8')
    print("gop() disabled")
else:
    print("gop() pattern not found or already disabled:", marker in s)
PY
grep -n "keys112\|^def gop" "$G" | head -5