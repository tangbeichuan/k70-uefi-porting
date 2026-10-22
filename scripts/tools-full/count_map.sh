set +e
F=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
echo "current entries in tree (should be restored):"; grep -c '^  {"' "$F"
python3 - <<'PY'
import pathlib,re
f=pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c')
s=f.read_text(encoding='utf-8',errors='surrogateescape')
n=len(re.findall(r'^\s*\{"', s, re.M))
print('entries currently:', n)
PY