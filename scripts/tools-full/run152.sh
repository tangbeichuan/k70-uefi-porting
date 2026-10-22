#!/usr/bin/env bash
# keys152 (baseline keys151 lineage + minimal prints-only Menu) and
# keys153 (keys149 FD repacked verbatim, regression baseline).
set -e -o pipefail
W=/mnt/d/本地项目-01/_k70port_extract/wsl
T=/mnt/d/本地项目-01/_tools
Q=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
OUT=/mnt/d/本地项目-01/K70-UEFI-build
cd "$W"

# ---------- generate the keys152 lineage from keys151 ----------
sed 's/keys151/keys152/g' build_keys151.sh > build_keys152.sh
sed 's/keys151/keys152/g' run_keys151.sh  > run_keys152.sh

python3 - <<'PY'
import pathlib
W = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl')

b = W / 'build_keys152.sh'
s = b.read_text()
anchor = 'python3 /mnt/d/本地项目-01/_tools/patch_menu101.py  # re-apply after gates.py'
assert anchor in s, 'menu anchor missing in build_keys152.sh'
if 'patch_usb152.py' not in s:
    s = s.replace(anchor, anchor + '\npython3 /mnt/d/本地项目-01/_tools/patch_usb152.py', 1)
b.write_text(s)
print('build_keys152.sh: patch_usb152 inserted after patch_menu101')

r = W / 'run_keys152.sh'
s = r.read_text()
old = '''grep -aq "BlockIO devices" "$MENUD" && echo "  OK: [UI] BlockIO devices display" \\
    || { echo "  MISSING BlockIO display"; exit 1; }'''
new = '''strings -el "$MENUD" | grep -q "MENU152" && echo "  OK: [MENU152] marker present" \\
    || { echo "  MISSING MENU152 marker"; exit 1; }'''
assert old in s, 'menu grep anchor missing in run_keys152.sh'
s = s.replace(old, new, 1)
r.write_text(s)
print('run_keys152.sh: Menu check switched to utf-16 "[MENU152]" marker')
PY

# ---------- build keys152 ----------
echo "=== building keys152 ==="
bash run_keys152.sh > "$T/b152.log" 2>&1 || { echo "BUILD FAILED"; tail -40 "$T/b152.log"; exit 1; }
tail -14 "$T/b152.log"
cp -f /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref "$T/guid-keys152.xref" || true
cp -f "$OUT/Mu-vermeer-keys152.img" "$OUT/K70-keys152-MINIMAL-MENU.img"

# ---------- keys153: repack keys149 FD verbatim ----------
echo "=== repacking keys149 FD as keys153 ==="
cp -f "$Q/SILICIUM_UEFI-keys149.fd" "$Q/SILICIUM_UEFI-keys153.fd"
bash pack_keys.sh "$Q/SILICIUM_UEFI-keys153.fd" keys153 > "$T/b153.log" 2>&1 || { echo "PACK FAILED"; tail -40 "$T/b153.log"; exit 1; }
tail -10 "$T/b153.log"
cp -f "$OUT/Mu-vermeer-keys153.img" "$OUT/K70-keys153-REPACK-BASELINE.img"

# ---------- summary ----------
echo "=== sha256 ==="
sha256sum "$Q/SILICIUM_UEFI-keys152.fd" "$OUT/Mu-vermeer-keys152.img" \
          "$Q/SILICIUM_UEFI-keys153.fd" "$OUT/Mu-vermeer-keys153.img" \
          "$OUT/K70-keys152-MINIMAL-MENU.img" "$OUT/K70-keys153-REPACK-BASELINE.img" \
          "$OUT/Mu-vermeer-keys149.img"
echo "=== comparison: keys153 img vs keys149 img (expect identical) ==="
cmp -s "$OUT/Mu-vermeer-keys153.img" "$OUT/Mu-vermeer-keys149.img" && echo "IDENTICAL" || echo "DIFFERENT"
echo "=== comparison: keys153 fd vs keys149 fd (expect identical) ==="
cmp -s "$Q/SILICIUM_UEFI-keys153.fd" "$Q/SILICIUM_UEFI-keys149.fd" && echo "IDENTICAL" || echo "DIFFERENT"
