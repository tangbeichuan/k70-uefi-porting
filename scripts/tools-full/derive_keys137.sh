#!/usr/bin/env bash
# Derive the keys137 build/run scripts from keys136 (sed 's/keys136/keys137/g'),
# then splice in the FAT-log-disk gate and the "-fat" image packaging.
#
# Run once:  bash derive_keys137.sh
set -e
W=/mnt/d/本地项目-01/_k70port_extract/wsl
T=/mnt/d/本地项目-01/_tools
cd "$W"

################################################################################
# build_keys137.sh
################################################################################
sed 's/keys136/keys137/g' build_keys136.sh > build_keys137.sh

# The FAT gate must run *after* patch_usb126.py, because that patch is what
# inserts the LogDisk INF into APRIORI.inc (right before the menu INF) and
# re-enables the USB device stack.  Running the gate earlier saw a package
# without the dispatch entry and failed.
sed -i '/patch_pmicstub127\.py/a python3 /mnt/d/本地项目-01/_tools/patch_fat137.py' build_keys137.sh

# replace the inherited keys136 narrative header with a keys137 one (keeping the
# lineage pointer, the code below it is unchanged apart from the tag)
python3 - "$W/build_keys137.sh" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
lines = p.read_text(encoding="utf-8").splitlines(True)
j = 1
while j < len(lines) and lines[j].lstrip().startswith("#"):
    j += 1
lines[1:j] = [
    "# keys137 = keys136 + FAT-formatted log disk (VermeerLogDiskDxe v2).\n",
    "#\n",
    "# The only change vs keys136 is the upgraded RAM log-disk driver: instead of\n",
    "# exposing raw 512-byte blocks it formats a real FAT volume with a\n",
    "# BOOTLOG.TXT inside, so a connected PC can mount the drive and copy the log\n",
    "# instead of photographing the screen.\n",
    "#\n",
    "# Unchanged on purpose: BlockIO media parameters (1 MiB, 512 B blocks, 2048\n",
    "# blocks), the \"[UI] BlockIO devices: 1\" menu line, and every patch in the\n",
    "# keys136 order - patch_usb126.py must stay, it is what re-inserts the\n",
    "# LogDisk INF into APRIORI.inc right before the menu (without it BlockIO\n",
    "# drops to 0).  patch_fat137.py verifies all of that and fails the build.\n",
    "#\n",
    "# keys136 lineage: keys13a - UFSDxe (the module the real-device log died in).\n",
]
p.write_text("".join(lines), encoding="utf-8")
print("build_keys137.sh: written, %d lines" % len(lines))
PY

################################################################################
# run_keys137.sh
################################################################################
sed 's/keys136/keys137/g' run_keys136.sh > run_keys137.sh

python3 - "$W/run_keys137.sh" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
lines = p.read_text(encoding="utf-8").splitlines(True)
out, replaced = [], False
for ln in lines:
    if ln.startswith("bash build_keys137.sh"):
        out.append('bash build_keys137.sh "$TAG" 2>&1 | tee /tmp/$TAG-build.log | tail -6\n')
    elif ln.startswith("bash pack_keys.sh"):
        out.append('bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG" 2>&1 | tee /tmp/$TAG-pack.log | tail -4\n')
        out.append('\n')
        out.append(
            '########################################################################\n'
            '# Artifact: the task asks for the FAT build under a "-fat" name.  The\x20\n'
            '# container bytes are identical to Mu-vermeer-<tag>.img (the FAT volume\n'
            '# lives inside the firmware), so just publish a copy under both names.\n'
            '########################################################################\n'
            'OUT=/mnt/d/本地项目-01/K70-UEFI-build\n'
            'cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/Mu-vermeer-$TAG-fat.img"\n'
            'echo "=== $TAG images ==="\n'
            'sha256sum "$OUT/Mu-vermeer-$TAG.img" "$OUT/Mu-vermeer-$TAG-fat.img"\n'
            '\n'
            '########################################################################\n'
            '# Prove the new driver and the unchanged boot display are in the build.\n'
            '########################################################################\n'
            'B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB\n'
            'LOGD=$(find "$B" -name \'VermeerLogDiskDxe.efi\' | head -1)\n'
            'MENUD=$(find "$B" -name \'VermeerMenuDxe.efi\' | head -1)\n'
            'echo "--- logdisk EFI: $LOGD ---"\n'
            'for pat in "volume ready" "FAT16] geometry" "selfcheck" "BOOTLOG" "K70 LOGDISK"; do\n'
            '    grep -aq "$pat" "$LOGD" && echo "  OK: $pat" || { echo "  MISSING: $pat"; exit 1; }\n'
            'done\n'
            'echo "--- menu EFI: $MENUD ---"\n'
            'grep -aq "BlockIO devices" "$MENUD" && echo "  OK: [UI] BlockIO devices display" \\\n'
            '    || { echo "  MISSING BlockIO display"; exit 1; }\n'
            'echo "--- FV module list ---"\n'
            'grep -i \'VermeerLogDiskDxe\' "/tmp/guid-$TAG.xref" || { echo "LOGDISK NOT IN FV"; exit 1; }\n'
            'echo "--- build log tail ---"\n'
            'tail -12 "/tmp/$TAG-build.log"\n'
        )
        replaced = True
    else:
        out.append(ln)
assert replaced, "pack_keys.sh line not found"
p.write_text("".join(out), encoding="utf-8")
print("run_keys137.sh: written, %d lines" % len(out))
PY

chmod +x build_keys137.sh run_keys137.sh
echo "--- build_keys137.sh: patches in order ---"
grep -n 'patch_\|gates.py\|build_uefi\|Build/vermeerPkg' build_keys137.sh
echo "--- run_keys137.sh ---"
cat run_keys137.sh
