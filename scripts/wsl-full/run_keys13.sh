#!/usr/bin/env bash
# Build keys13b (-NpaDxe), then keys13a (+ULogDxe), and pack each into three boot images.
# Every build script restores vermeer.dsc/fdf on exit, so running them back to back is safe.
set -e -o pipefail

TOOLS=/mnt/d/本地项目-01/_k70port_extract
OUT=/mnt/d/本地项目-01/K70-UEFI-build

build_pack() {
  local mode="$1" tag="$2"
  echo "################## BUILD $tag (mode $mode) ##################"
  bash "$TOOLS/wsl/build_keys13.sh" "$mode"
  echo "################## PACK $tag ##################"
  bash "$TOOLS/wsl/pack_keys.sh" "$TOOLS/qemu-fw/SILICIUM_UEFI-$tag.fd" "$tag"
}

build_pack B keys13b
build_pack A keys13a

echo "################## RESULT ##################"
ls -l "$OUT"/Mu-vermeer-keys13*.img
sha256sum "$OUT"/Mu-vermeer-keys13*.img
