#!/usr/bin/env bash
set -e
B=/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys157.sh
grep -nE 'MENU|USB1[0-9]{2}|VermeerMenuDxe|pack_keys|build_uefi' "$B" | head -40
