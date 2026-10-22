#!/usr/bin/env bash
# Refresh the port source tarball so it carries everything needed to reproduce the
# build, including the BootShim bring-up marker and the two build_uefi.py patches.
set -e
cd /root/k70/uefi || exit 1
OUT=/mnt/d/本地项目-01/K70-UEFI-build
UP=/mnt/d/本地项目-01/_k70port_extract/upstream-patches
SRC=/root/k70/vermeer-port-src
rm -rf "$SRC"
mkdir -p "$SRC"/{Platforms/Xiaomi,Resources/Configs,Resources/DTBs,Resources/MuPatches,Binaries,upstream-patches/shims,docs}

cp -a Platforms/Xiaomi/vermeerPkg            "$SRC/Platforms/Xiaomi/"
cp -a Binaries/vermeer                      "$SRC/Binaries/"
cp -a Resources/Configs/vermeer.toml        "$SRC/Resources/Configs/"
cp -a Resources/DTBs/vermeer.dtb            "$SRC/Resources/DTBs/"
cp -a Resources/MuPatches/*.patch           "$SRC/Resources/MuPatches/"

# build_uefi.py patches (as applied) + the resulting file for reference
cp "$UP"/BootShim.S.marker "$UP"/BootShim.Makefile.marker \
   "$UP"/patch_build_uefi_marker.py "$UP"/patch_build_uefi_gzip.py "$SRC/upstream-patches/"
cp build_uefi.py "$SRC/upstream-patches/build_uefi.py.patched"
cp BootShim/BootShim.S "$SRC/upstream-patches/BootShim.S.installed"
cp BootShim/Makefile   "$SRC/upstream-patches/BootShim.Makefile.installed"
cp /root/k70/shims/BootShim-marker0.bin /root/k70/shims/BootShim-marker1.bin "$SRC/upstream-patches/shims/"

# the release docs live next to the binaries on the Windows side
cp "$OUT"/{README-BUILD.md,VERIFY-REPORT.txt} "$SRC/docs/" 2>/dev/null || true

cat > "$SRC/docs/HOW-TO-REBUILD.md" <<'MD'
# Rebuilding the vermeer UEFI firmware

Host prerequisites (Ubuntu 24.04/26.04, tested on 26.04.1 with clang 21.1.8):

    apt install build-essential uuid-dev python3-venv python3-pip nasm iasl \
                device-tree-compiler mtools ninja-build clang lld llvm libssl-dev \
                bc ccache dosfstools xz-utils mono-complete
    python3 -m venv /root/k70/venv && . /root/k70/venv/bin/activate
    pip install edk2-pytool-extensions

Checkout and submodules:

    git clone -b sheng https://github.com/UniXNU/uefi-sheng.git /root/k70/uefi
    cd /root/k70/uefi
    git submodule update --init Common/Mu Common/Mu_OEM_Sample Mu_Basecore \
        Silicium-ACPI Silicon/Silicium/OpensslPkg/Library/OpensslLib/openssl
    # Mu_Basecore has nested submodules that the build needs:
    git -C Mu_Basecore submodule update --init --recursive \
        MdePkg/Library/MipiSysTLib/mipisyst MdePkg/Library/BaseFdtLib/libfdt \
        MdeModulePkg/Library/BrotliCustomDecompressLib/brotli \
        BaseTools/Source/C/BrotliCompress/brotli \
        SecurityPkg/DeviceSecurity/SpdmLib/libspdm
    # The "Binaries" submodule is deliberately NOT initialised, we ship Binaries/vermeer.
    # BaseTools nasm never runs on AARCH64, and its NuGet fetch is unreliable:
    mv Mu_Basecore/BaseTools/Bin/nasm_ext_dep.yaml{,.disabled}
    git config --global --add safe.directory '*'

Drop this tree's contents into the checkout, then:

    python3 upstream-patches/patch_build_uefi_marker.py build_uefi.py
    python3 upstream-patches/patch_build_uefi_gzip.py  build_uefi.py
    # optional: drop the 5 GB submodule clone from DeviceBuild.py (vermeer ships its own)
    # Platforms/Xiaomi/vermeerPkg/DeviceBuild.py -> RequiredSubmodule ("Binaries", True) commented out
    python3 build_uefi.py -d vermeer -m 0 -r DEBUG

Products:

    Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd     (3 MiB, the firmware volume)
    Build/vermeerPkg/vermeer-kernel                          (gzip(shim||FV) || DTB)
    Mu-vermeer.img                                           (Android boot image v1)

`paint_marker = true` in `Resources/Configs/vermeer.toml` builds the diagnostic
BootShim that paints progress bands; see docs / the release notes section 8.9.
MD

cd "$SRC"
tar --sort=name --owner=0 --group=0 --numeric-owner -czf "$OUT/vermeer-port-src-20261020.tar.gz" .
cd "$OUT"
echo "tarball: $(stat -c %s vermeer-port-src-20261020.tar.gz) bytes, files: $(tar -tzf vermeer-port-src-20261020.tar.gz | wc -l)"
sha256sum vermeer-port-src-20261020.tar.gz
