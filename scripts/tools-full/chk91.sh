set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys90/keys91/g; s/bak90/bak91/g' run_keys90.sh > run_keys91.sh
python3 - <<'PY'
import pathlib
p=pathlib.Path('run_keys91.sh'); s=p.read_text(encoding='utf-8')
anchor='python3 /mnt/d/本地项目-01/_tools/patch_ufsmap84.py "$PKG"'
assert anchor in s
inject = ('MM=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c\n'
          'cp "$MM" /tmp/MemoryMapLib.c.bak91\n'
          'trap \'cp /tmp/MemoryMapLib.c.bak91 "$MM"\' EXIT\n'
          'python3 /mnt/d/本地项目-01/_tools/ins_ufsmap91.py\n')
s=s.replace(anchor, inject + anchor, 1)
p.write_text(s,encoding='utf-8'); print('run_keys91: memmap inject ready')
PY
bash run_keys91.sh keys91 > /tmp/k91.log 2>&1; echo "run exit=$?"
grep -nE "UFS entry|apriori: probe inserted|ERROR|PROGRESS - Success" /tmp/k91.log | head -6
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys91.fd" keys91 2>&1 | tail -3