#!/usr/bin/env bash
set -eu
OUT=/mnt/d/本地项目-01/K70-UEFI-build
QV=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
cp -f "$OUT/Mu-vermeer-keys147d.img" "$OUT/K70-keys147d-USBDIAG.img"
sha256sum "$OUT/Mu-vermeer-keys147d.img" "$OUT/K70-keys147d-USBDIAG.img" "$QV/SILICIUM_UEFI-keys147d.fd"
ls -l "$OUT/K70-keys147d-USBDIAG.img"
