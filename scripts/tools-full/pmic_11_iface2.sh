#!/bin/bash
cd /mnt/d/本地项目-01/_tools || exit 1
for t in 0x991c 0x9984 0x9954; do
  echo "##### $t"
  python3 pmic_10_callsites.py "$t" 10 2>&1 | head -90
done
