#!/bin/bash
P=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== APRIORI.inc (current, post-build-restore) ==="
grep -vn '^\s*$' $P/Include/APRIORI.inc | sed -n '1,140p'
