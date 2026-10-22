#!/usr/bin/env bash
# Clean rebuild of the default Mu-only configuration: proves the tree builds from
# scratch (not just incrementally) and gives an authoritative module list.
set +e
cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate
rm -rf Build/vermeerPkg
rm -f Mu-vermeer.img
echo "=== clean build (no Build/vermeerPkg) ==="
time python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/build-clean.log 2>&1
rc=$?
echo "rc=$rc"
grep -E 'FVMAIN \[|FVMAIN_COMPACT \[|Images Verified' /root/k70/build-clean.log | sed 's/^INFO - //'
sha256sum Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd Mu-vermeer.img 2>/dev/null

echo
echo "=== modules actually compiled (AutoGen.obj lines) ==="
grep -oE 'AARCH64/[^ ]*/OUTPUT/(\./)?AutoGen\.obj' /root/k70/build-clean.log | sed -E 's#AARCH64/##; s#/OUTPUT/.*##' | awk -F/ '{print $NF}' | sort -u > /tmp/mods_clean.txt
echo "count: $(wc -l < /tmp/mods_clean.txt)"
tr '\n' ' ' < /tmp/mods_clean.txt; echo
