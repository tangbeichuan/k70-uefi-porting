#!/bin/bash
B=/mnt/d/本地项目-01/_k70port_extract/_upstream
for d in "$B"/UniXNU__*; do
  echo "=== $d"
  ls -1 "$d" | head -12
  if [ -f "$d/README.md" ]; then echo "--- README head ---"; head -18 "$d/README.md"; fi
  echo
done
