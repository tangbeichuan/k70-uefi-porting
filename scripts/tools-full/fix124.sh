set +e
I=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.inf
grep -n 'Protocols\|Guid' "$I"
if ! grep -q 'gEfiBlockIoProtocolGuid' "$I"; then
python3 - <<'PY'
import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.inf')
s = p.read_text(encoding='utf-8')
if '[Protocols]' in s:
    s = s.replace('[Protocols]', '[Protocols]\n  gEfiBlockIoProtocolGuid', 1)
else:
    s = s.rstrip('\n') + '\n\n[Protocols]\n  gEfiBlockIoProtocolGuid\n'
p.write_text(s, encoding='utf-8')
print('inf patched')
PY
fi
grep -n 'gEfiBlockIoProtocolGuid' "$I"
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys124.sh 2>&1 | tail -8