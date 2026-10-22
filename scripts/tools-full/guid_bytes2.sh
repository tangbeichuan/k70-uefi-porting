set +e
python3 - <<'PY'
import pathlib
m = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV')
menu = bytes.fromhex('2E1C7A4FB593684DA1E76C2B8F5D3A90')   # 4F7A1C2E-93B5-4D68-A1E7-6C2B8F5D3A90 (mixed-endian)
sfb  = bytes.fromhex('6D1EFDDC8D78FC4F1B8ECA2F75651A92')   # DCFD1E6D-788D-4FFC-8E1B-CA2F75651A92
for name in ('FVMAIN.Fv','FVMAIN_COMPACT.Fv','SILICIUM_UEFI.fd'):
    p=m/name
    b=p.read_bytes()
    print(f"{name:20s} size={len(b):9d} menu={b.count(menu)} simplefb={b.count(sfb)}")
PY