set +e
U=/root/k70/uefi
INC="$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc"
TAG=${1:-keys54}
cp "$INC" /tmp/SiliciumPkg.dsc.inc.bak54
restore() { cp /tmp/SiliciumPkg.dsc.inc.bak54 "$INC"; echo "[restored] $INC"; }
trap restore EXIT
python3 - "$INC" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8',errors='replace').read()
old="gEfiMdePkgTokenSpaceGuid.PcdDebugPrintErrorLevel|0x8007EE0F"
new="gEfiMdePkgTokenSpaceGuid.PcdDebugPrintErrorLevel|0x80000004"
assert old in s, "PCD line not found"
s=s.replace(old,new,1)
open(p,'w',encoding='utf-8').write(s)
print("patched debug error level -> 0x80000004 (ERROR|LOAD)")
PY
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys53.sh "$TAG"
echo "=== pack ==="
bash /mnt/d/本地项目-01/_k70port_extract/wsl/pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG" 2>&1 | tail -4