#!/bin/bash
Q=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
K=/mnt/d/本地项目-01/K70-UEFI-build
for f in $Q/SILICIUM_UEFI-keys149.fd $Q/SILICIUM_UEFI-keys150.fd $K/Mu-vermeer-keys149.img $K/Mu-vermeer-keys150.img $K/K70-keys151-NO-PEI-CHANGE.img $K/K70-keys151b-USBROW-REMOVED.img; do
  [ -f "$f" ] && sha256sum "$f"
done
