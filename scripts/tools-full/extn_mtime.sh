set +e
E=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerDtbExtnDxe.efi
ls -l --time-style=+%H:%M:%S "$E" | cat
python3 - "$E" <<'PY'
import sys,struct
d=open(sys.argv[1],'rb').read()
print("size",len(d))
print("has 'slot 0xa0':", d.find(b'slot 0xa0'))
print("has 'get prop':", d.find(b'get prop'))
PY