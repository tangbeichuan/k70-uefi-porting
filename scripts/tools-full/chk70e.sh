set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 - <<'PY'
import io
src='run_keys69.sh'
s=io.open(src,encoding='utf-8',errors='replace').read()
s=s.replace('TAG=${1:-keys69}','TAG=${1:-keys70}',1)
marker='# ---- 4) 编译 + 打包 -------------------------------------------------------------'
assert marker in s, 'marker missing'
hard='''# ---- 3b) 硬编码剔除 HALIOMMU（DROP token 机制对它无效，单独处理） ------------
python3 - "$PKG" <<'PY2'
import sys, pathlib
pkg = pathlib.Path(sys.argv[1]); n = 0
for name in ("vermeer.dsc", "vermeer.fdf", "Include/DXE.inc", "Include/APRIORI.inc"):
    p = pkg / name
    if not p.exists():
        continue
    out = []
    for line in p.read_text(encoding="utf-8").splitlines(keepends=True):
        if "HALIOMMUDxe" in line and not line.lstrip().startswith("#"):
            out.append("# [keys70-hard] " + line); n += 1
        else:
            out.append(line)
    p.write_text("".join(out), encoding="utf-8")
print("hard-dropped HALIOMMU lines:", n)
PY2

'''
s=s.replace(marker, hard+marker,1)
io.open('run_keys70.sh','w',encoding='utf-8').write(s)
print('run_keys70.sh written')
PY
bash run_keys70.sh keys70 > /tmp/k70.log 2>&1; echo "exit=$?"
grep -nE 'hard-dropped|kept vendor|dropped lines|UFSDxe kept|Success' /tmp/k70.log | tail -6
echo "=== FVMAIN 里 9A00771F / PmicDxe(6D4A9CF7) / UFSDxe(0D35CD8E) ==="
for g in 9A00771F 6D4A9CF7 0D35CD8E 5B21E7C4; do printf "%s : " $g; grep -c "$g" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt; done
echo "=== FVMAIN 条目数 / FD sha ==="
grep -c '^0x' /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt
sha256sum /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys70.fd