#!/bin/bash
set -u
for f in \
  "/mnt/d/本地项目-01/_k70_pkg_1019/K70-UEFI-package/extracted/xbl_config_fdt_cb20.dtb" \
  "/mnt/d/本地项目-01/_k70_pkg_1019/K70-UEFI-package/extracted/xbl_config_fdt_10168.dtb" \
  "/mnt/d/本地项目-01/_k70port_extract/port/Resources/DTBs/vermeer.dtb" \
  "/mnt/d/本地项目-01/_k70port_extract/k70-port/extracted/vermeer-live.dtb"
do
  echo "== $f"
  if [ -f "$f" ]; then
    grep -aob 'transact' "$f" | head -5 || true
    grep -aob 'iort' "$f" | head -3 || true
  else
    echo "   (missing)"
  fi
done
