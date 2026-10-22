#!/usr/bin/env bash
# Refresh the source-tree tarball with the as-built port (now including the
# gated VermeerPaintDxe driver) and copy the as-built config files out.
set -euo pipefail
UEFI=/root/k70/uefi
STAGE=/root/k70/vermeer-port-src
OUT=/mnt/d/本地项目-01/K70-UEFI-build
PKG=$UEFI/Platforms/Xiaomi/vermeerPkg

mkdir -p "$STAGE"
rm -rf "$STAGE/Platforms" "$STAGE/Binaries" "$STAGE/Resources"
mkdir -p "$STAGE/Platforms/Xiaomi" "$STAGE/Resources/Configs" "$STAGE/Resources/DTBs"

rsync -a "$PKG" "$STAGE/Platforms/Xiaomi/"
rsync -a "$UEFI/Binaries/vermeer" "$STAGE/Binaries/"
cp "$UEFI/Resources/Configs/vermeer.toml" "$STAGE/Resources/Configs/"
cp "$UEFI/Resources/DTBs/vermeer.dtb"     "$STAGE/Resources/DTBs/"
mkdir -p "$STAGE/Resources/MuPatches"
rsync -a "$UEFI/Resources/MuPatches/" "$STAGE/Resources/MuPatches/"

# layer-0 probe (docs 8.12): a 256-byte payload with no firmware in it, plus the
# scripts that build and verify it
mkdir -p "$STAGE/diagnostic/paint-only"
cp /mnt/d/本地项目-01/_k70port_extract/payload-paint/paint_only.S \
   /mnt/d/本地项目-01/_k70port_extract/verify_paint_only.py \
   /mnt/d/本地项目-01/_k70port_extract/wsl/build_paint_only.sh \
   "$STAGE/diagnostic/paint-only/"

# QEMU execution harness (docs 8.13): boots the real FD under qemu-system-aarch64, dumps
# the frame-buffer serial window and renders it to a PNG
mkdir -p "$STAGE/diagnostic/qemu"
cp /mnt/d/本地项目-01/_k70port_extract/wsl/qemu_firmware_boot.sh \
   /mnt/d/本地项目-01/_k70port_extract/wsl/qemu_boot_variant.sh \
   /mnt/d/本地项目-01/_k70port_extract/wsl/qemu_bringup_build.sh \
   /mnt/d/本地项目-01/_k70port_extract/wsl/qemu_boundary_test2.sh \
   /mnt/d/本地项目-01/_k70port_extract/wsl/qemu_serial_build.sh \
   /mnt/d/本地项目-01/_k70port_extract/wsl/qemu_serial_boot.sh \
   /mnt/d/本地项目-01/_k70port_extract/wsl/qemu_psci_check.sh \
   /mnt/d/本地项目-01/_k70port_extract/render_fb.py \
   "$STAGE/diagnostic/qemu/"
cp /mnt/d/本地项目-01/K70-UEFI-build/QEMU-REPORT.txt "$STAGE/diagnostic/qemu/"
cp /mnt/d/本地项目-01/K70-UEFI-build/qemu-serial-boot.log "$STAGE/diagnostic/qemu/"
cp /mnt/d/本地项目-01/K70-UEFI-build/qemu-smc-evidence.txt "$STAGE/diagnostic/qemu/"

# pre-flight audits (docs 8.15): memory map vs the stock description, MMIO constants vs the
# device tree - both answer questions a black screen cannot answer afterwards
mkdir -p "$STAGE/diagnostic/preflight"
cp /mnt/d/本地项目-01/_k70port_extract/audit_memory_map.py \
   /mnt/d/本地项目-01/_k70port_extract/audit_soc_addresses.py \
   "$STAGE/diagnostic/preflight/"

# container coverage + stock capture (docs 8.14): the v0..v4 parser, the container
# verifier, the v2/v3 builder and the read-only phone capture script
mkdir -p "$STAGE/diagnostic/containers"
cp /mnt/d/本地项目-01/_k70port_extract/parse_bootimg.py \
   /mnt/d/本地项目-01/_k70port_extract/verify_containers.py \
   /mnt/d/本地项目-01/_k70port_extract/wsl/build_hdr_variants.sh \
   /mnt/d/本地项目-01/K70-UEFI-build/capture-stock.ps1 \
   "$STAGE/diagnostic/containers/"

# banner + heartbeat driver (docs 8.17): the only image that shows the firmware is alive on
# the panel without scrolling logs; verified in QEMU (heartbeats 1..80, "ConOut ok")
mkdir -p "$STAGE/diagnostic/banner"
cp /mnt/d/本地项目-01/_k70port_extract/wsl/build_banner.sh \
   /mnt/d/本地项目-01/_k70port_extract/wsl/build_banner_qemu.sh \
   /mnt/d/本地项目-01/_k70port_extract/wsl/qemu_banner_test.sh \
   /mnt/d/本地项目-01/_k70port_extract/wsl/pack_banner.sh \
   "$STAGE/diagnostic/banner/"
cp "$PKG/Drivers/VermeerBannerDxe/VermeerBannerDxe.c"   "$STAGE/diagnostic/banner/"
cp "$PKG/Drivers/VermeerBannerDxe/VermeerBannerDxe.inf" "$STAGE/diagnostic/banner/"
cp /mnt/d/本地项目-01/_k70port_extract/qemu-fw/qemu-serial-banner.log "$STAGE/diagnostic/banner/" 2>/dev/null || true

# PCD audit (docs 8.20): proves the shipped binaries target the phone's GIC (0x17100000) and not
# the QEMU virt GIC (0x08000000), by disassembling the decompressed module code.
mkdir -p "$STAGE/diagnostic/pcd-audit"
cp /mnt/d/本地项目-01/_k70port_extract/check_gic_pcds.py \
   /mnt/d/本地项目-01/_k70port_extract/check_fb_pcds.py \
   "$STAGE/diagnostic/pcd-audit/"
cp /mnt/d/本地项目-01/_k70port_extract/wsl/audit_pcds.sh "$STAGE/diagnostic/pcd-audit/"
cp /mnt/d/本地项目-01/K70-UEFI-build/PCD-AUDIT.txt          "$STAGE/diagnostic/pcd-audit/"

# operator-side automation (docs 8.18/8.19): the interactive ladder and its short entry card.
# These are the only files a human at the phone actually runs.
mkdir -p "$STAGE/diagnostic/operator"
cp /mnt/d/本地项目-01/K70-UEFI-build/run-ladder.ps1 "$STAGE/diagnostic/operator/"
cp /mnt/d/本地项目-01/K70-UEFI-build/START-HERE.md   "$STAGE/diagnostic/operator/"
cp /mnt/d/本地项目-01/K70-UEFI-build/test-boot.ps1   "$STAGE/diagnostic/operator/"

# as-built configuration files that the delivery folder documents
cp "$PKG/vermeer.dsc"                  "$OUT/vermeer.dsc"
cp "$PKG/vermeer.fdf"                  "$OUT/vermeer.fdf"
cp "$UEFI/Resources/Configs/vermeer.toml" "$OUT/vermeer.toml"
cp "$PKG/Library/MemoryMapLib/MemoryMapLib.c"             "$OUT/MemoryMapLib.c"
cp "$PKG/Library/ConfigurationMapLib/ConfigurationMapLib.c" "$OUT/ConfigurationMapLib.c"
cp "$PKG/Drivers/VermeerPaintDxe/VermeerPaintDxe.c"   "$OUT/VermeerPaintDxe.c"
cp "$PKG/Drivers/VermeerPaintDxe/VermeerPaintDxe.inf" "$OUT/VermeerPaintDxe.inf"
cp "$PKG/Drivers/VermeerBannerDxe/VermeerBannerDxe.c"   "$OUT/VermeerBannerDxe.c"
cp "$PKG/Drivers/VermeerBannerDxe/VermeerBannerDxe.inf" "$OUT/VermeerBannerDxe.inf"

# record the gates that shaped this build
{
  echo "gates in the shipped configuration (vermeer.dsc [Defines])"
  grep -E '^\s+(USE_CUSTOM_DISPLAY_DRIVER|VERMEER_VENDOR_HW|VERMEER_PAINT|VERMEER_BANNER)' "$PKG/vermeer.dsc"
  echo
  echo "VermeerPaintDxe only reaches the FV when VERMEER_PAINT = 1."
  echo "VermeerBannerDxe only reaches the FV when VERMEER_BANNER = 1 (and never returns)."
  echo "Both are 0 in the shipping configuration."
} > "$OUT/BUILD-GATES.txt"

cd "$STAGE"
tar czf "$OUT/vermeer-port-src-20261020.tar.gz" .
cd "$OUT"
ls -l vermeer-port-src-20261020.tar.gz
tar tzf vermeer-port-src-20261020.tar.gz | wc -l
sha256sum vermeer-port-src-20261020.tar.gz
