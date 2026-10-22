#!/bin/bash
set -e
F=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv
xxd -s 0x50 -l 0x120 "$F"
echo '--- FVMAIN.inf head ---'
sed -n '1,40p' /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.inf
