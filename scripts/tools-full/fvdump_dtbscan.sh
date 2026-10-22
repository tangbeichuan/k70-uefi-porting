#!/bin/bash
D=/mnt/d/本地项目-01/_k70port_extract/fv_dump
echo "=== modules in stock FV mentioning DtbExtn/Fdt ==="
find $D -name '*.efi' | while read -r f; do
  m=$(strings -n 6 "$f" 2>/dev/null | grep -iE 'dtbextn|dtb extn|fdt table|device tree' | head -3)
  if [ -n "$m" ]; then echo "--- $(basename $f) ($(stat -c%s $f) B)"; echo "$m" | sed 's/^/      /'; fi
done | head -60
echo
echo "=== count of dumped modules ==="
find $D -name '*.efi' | wc -l
