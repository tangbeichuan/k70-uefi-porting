#!/usr/bin/env bash
# Initialize only the submodules a board build actually needs (skip Binaries: we ship verneer's own).
set -o pipefail
cd /root/k70/uefi || exit 1
echo "===== submodule update (depth 1) ====="
git submodule update --init --depth 1 -- \
  Common/Mu Common/Mu_OEM_Sample Mu_Basecore Silicium-ACPI \
  Silicon/Silicium/OpensslPkg/Library/OpensslLib/openssl 2>&1 | tail -20
echo "submodule exit: $?"
echo
echo "===== sizes ====="
du -sh Common/Mu Common/Mu_OEM_Sample Mu_Basecore Silicium-ACPI \
       Silicon/Silicium/OpensslPkg/Library/OpensslLib/openssl 2>/dev/null
du -sh /root/k70/uefi
echo
echo "===== pip-requirements.txt ====="
cat pip-requirements.txt
echo
echo "===== setup_env.sh ====="
cat setup_env.sh
echo
echo "===== Platforms/Xiaomi ====="
ls Platforms/Xiaomi
echo
echo "===== Resources ====="
find Resources -maxdepth 2 -type f | head -20
