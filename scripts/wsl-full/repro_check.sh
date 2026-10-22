#!/usr/bin/env bash
# Second from-scratch build, to see whether the FD is bit-reproducible or carries
# a build timestamp (identical sizes + different sha would prove the latter).
set +e
cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate
cp -f Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd /root/k70/fd-clean-1.fd
cp -f Mu-vermeer.img /root/k70/img-clean-1.img
rm -rf Build/vermeerPkg
rm -f Mu-vermeer.img
python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/build-clean2.log 2>&1
echo "rc=$?"
grep -E 'FVMAIN \[|Images Verified' /root/k70/build-clean2.log | sed 's/^INFO - //'
echo
echo "=== two independent from-scratch builds ==="
sha256sum /root/k70/fd-clean-1.fd Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
sha256sum /root/k70/img-clean-1.img Mu-vermeer.img
echo
echo "byte diff count between the two FDs:"
cmp -l /root/k70/fd-clean-1.fd Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd 2>/dev/null | wc -l
