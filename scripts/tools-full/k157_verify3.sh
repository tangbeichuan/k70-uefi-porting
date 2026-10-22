#!/usr/bin/env bash
set -e
M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
echo "--- pkg Menu tail (MENU157 region) ---"
grep -n 'MENU157\|USB157\|for (;;)\|ReadKeyStroke (mIn' "$M"
echo "--- tail 40 lines ---"
tail -45 "$M"
