#!/bin/bash
f=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
echo "rows=$(grep -cE '^[[:space:]]*\{' "$f")"
echo "usb_lines:"; grep -nE '"USB"|0x0A600000' "$f"
echo "--- around line 55-70 ---"; sed -n '55,70p' "$f"
echo "--- mtime ---"; ls -l "$f"
