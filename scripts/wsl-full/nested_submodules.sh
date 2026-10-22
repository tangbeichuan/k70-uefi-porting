#!/usr/bin/env bash
# Mu_Basecore has its own nested submodules (libfdt, mipi-sys-t, brotli, ...).
# MdePkg.dec references them, so the FD build fails without them.
set +e
cd /root/k70/uefi/Mu_Basecore || exit 1
for p in MdePkg/Library/MipiSysTLib/mipisyst \
         MdePkg/Library/BaseFdtLib/libfdt \
         MdeModulePkg/Library/BrotliCustomDecompressLib/brotli \
         BaseTools/Source/C/BrotliCompress/brotli; do
  echo "===== $p ====="
  git submodule update --init --depth 1 "$p" 2>&1 | tail -2
  ls -d "$p" >/dev/null 2>&1 && echo "  present" || echo "  MISSING"
done
echo
echo "===== references from MdePkg.dec / *.dsc that might still be missing ====="
grep -rn 'Library/' /root/k70/uefi/Mu_Basecore/MdePkg/MdePkg.dec | sed -n '1,6p'
