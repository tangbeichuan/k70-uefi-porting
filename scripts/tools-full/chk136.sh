set +e
python3 - <<'PY'
import pathlib
fd = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys136.fd')
d = fd.read_bytes()
pro = bytes.fromhex('b4513c7a629e1f4d8c0a2b5e6d7f1a93')
dt  = bytes.fromhex('3a1c5b7e249d774e9c1b2a6d5f8e4c31')
print('FD size', len(d), 'provider:', d.count(pro), 'dt:', d.count(dt))
PY