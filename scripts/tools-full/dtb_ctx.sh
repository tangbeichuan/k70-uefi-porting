#!/bin/bash
set -u
F="/mnt/d/本地项目-01/_k70port_extract/port/Resources/DTBs/vermeer.dtb"
for off in 788669 799375; do
  echo "== around $off"
  dd if="$F" bs=1 skip=$((off-160)) count=260 2>/dev/null | strings -n 3
done
