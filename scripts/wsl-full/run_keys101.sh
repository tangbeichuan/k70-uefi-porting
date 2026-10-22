#!/usr/bin/env bash
# keys101 = keys14 vendor baseline + a LATE menu driver (volume keys must work)
set -e -o pipefail
TAG=keys101
TOOLS=/mnt/d/本地项目-01/_k70port_extract
cd /mnt/d/本地项目-01/_k70port_extract/wsl

# 1) copy the driver into the package and stage the dsc/APRIORI patch script
python3 /mnt/d/本地项目-01/_tools/patch_menu101.py

# 2) derive the build script, and make it re-apply the dsc/APRIORI patch AFTER gates.py
sed 's/keys14/keys101/g' build_keys14.sh > build_keys101.sh
chmod +x build_keys101.sh

python3 - <<'PY'
import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys101.sh')
s = p.read_text(encoding='utf-8')
inject = '\npython3 /mnt/d/本地项目-01/_tools/patch_menu101.py  # re-apply after gates.py\n'
if 're-apply after gates.py' not in s:
    out = []
    for ln in s.splitlines(True):
        out.append(ln)
        if 'gates.py' in ln and 'keyprobe' in ln:
            out.append(inject)
    p.write_text(''.join(out), encoding='utf-8')
    print('build_keys101.sh: injected patch after gates.py')
else:
    print('build_keys101.sh: already injected')
PY

bash build_keys101.sh "$TAG"
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG"