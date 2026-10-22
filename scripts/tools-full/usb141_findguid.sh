#!/usr/bin/env bash
set +e
cd /root/k70/uefi || exit 1
for g in B0760469 FA5F306B F4E5C7D0 157A5C45 EB97088E 4684800A AE37B942 CD823A4D; do
  echo "=== $g ==="
  grep -rIl "$g" --include='*.h' --include='*.c' --include='*.dec' --include='*.dsc' --include='*.inf' . 2>/dev/null | head -6
done
echo "=== also search _k70port_extract ==="
grep -rIl "4684800A\|FA5F306B\|B0760469" /mnt/d/本地项目-01/_k70port_extract --include='*.c' --include='*.h' 2>/dev/null | head -10
