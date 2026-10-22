set +e
python3 - <<'PY'
import pathlib
fv = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv')
fd = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys135.fd')
d1 = fv.read_bytes() if fv.exists() else b''
d2 = fd.read_bytes() if fd.exists() else b''
pro = bytes.fromhex('b4513c7a629e1f4d8c0a2b5e6d7f1a93')
dt  = bytes.fromhex('3a1c5b7e249d774e9c1b2a6d5f8e4c31')
menu= bytes.fromhex('2e1c7a4fb593684da1e76c2b8f5d3a90')
for name, blob in (('FVMAIN', d1), ('FD', d2)):
    print(name, len(blob), 'provider:', blob.count(pro), 'dt:', blob.count(dt), 'menu:', blob.count(menu))
# also search for the provider debug string
s = b'vermeer dtb-extn provider'
print('FVMAIN has provider string:', d1.find(s))
PY