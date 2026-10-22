#!/usr/bin/env bash
F=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
wc -l "$F"
echo "=== rows mentioning region names / USB / GCC / UFS ==="
grep -n 'USB' "$F"
grep -n 'GCC' "$F"
grep -n 'UFS' "$F"
grep -n 'PERIPH_SS' "$F"
echo "=== lines 30..77 ==="
sed -n '30,77p' "$F"
