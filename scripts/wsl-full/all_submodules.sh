#!/usr/bin/env bash
# Initialise every nested submodule (Mu_Basecore and friends). Breadth-first:
# the EDK2 meta-data pass walks every DEC in the package path and fails on the
# first missing include directory, so partial init just moves the error around.
set +e
for repo in /root/k70/uefi/Mu_Basecore /root/k70/uefi/Common/Mu /root/k70/uefi/Common/Mu_OEM_Sample /root/k70/uefi/Silicium-ACPI /root/k70/uefi/Silicon/Qualcomm /root/k70/uefi/Silicon/Silicium; do
  [ -d "$repo/.git" ] || [ -f "$repo/.git" ] || continue
  echo "===== $repo ====="
  ( cd "$repo" && git submodule update --init --recursive --depth 1 2>&1 | tail -6 )
done
echo
echo "===== remaining uninitialised submodules ====="
for repo in /root/k70/uefi/Mu_Basecore /root/k70/uefi/Common/Mu /root/k70/uefi/Silicium-ACPI /root/k70/uefi/Silicon/Silicium; do
  [ -d "$repo" ] || continue
  ( cd "$repo" && git submodule status 2>/dev/null | grep -c '^-' | sed "s|^|  $repo: |" )
done
