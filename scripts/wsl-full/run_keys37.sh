#!/bin/bash
# keys37 = keys25 lineage, but PlatformPeiLib stays the NULL implementation (no DTB Extension HOB,
#          so EnvDxe cannot dereference the bogus interface and the vendor stack survives), and the
#          probe is dispatched last so ConIn/ConOut are already up.  Driver does the UI demo only.
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys37

python3 /mnt/d/本地项目-01/_tools/make_build37.py || exit 1

bash build_keys37.sh "$TAG" || exit 1
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$TAG" || exit 1
echo "=== keys37 done ==="
