set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys146/keys147b/g' build_keys146.sh > build_keys147b.sh
sed 's/keys146/keys147b/g' run_keys146.sh > run_keys147b.sh
chmod +x build_keys147b.sh run_keys147b.sh
# insert the VBUS patch right after the extn136 patch line
python3 - <<'PY'
import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys147b.sh')
s = p.read_text()
anchor = 'python3 /mnt/d/本地项目-01/_tools/patch_copy123.py && python3 /mnt/d/本地项目-01/_tools/patch_extn136.py'
assert anchor in s, 'anchor missing'
if 'patch_usbvbus147.py' not in s:
    s = s.replace(anchor, anchor + '\npython3 /mnt/d/本地项目-01/_tools/patch_usbvbus147.py', 1)
p.write_text(s)
print('patched build script, has usbvbus:', 'patch_usbvbus147.py' in s)
PY
grep -n 'patch_usbvbus147\|patch_extn136\|keys147b' build_keys147b.sh | head -10