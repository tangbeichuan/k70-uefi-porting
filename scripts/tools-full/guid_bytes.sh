set +e
FV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
python3 - <<'PY'
import pathlib, binascii
guid = bytes.fromhex('6D1EFDDC8D788D4FFC8E1BCA2F75651A92')
m = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV')
for name in ('FVMAIN.Fv','FVMAIN_COMPACT.Fv','SILICIUM_UEFI.fd'):
    p = m/name
    if not p.exists(): continue
    b = p.read_bytes()
    print(name, 'size', len(b), 'SimpleFbGUID hits:', b.count(guid))
PY