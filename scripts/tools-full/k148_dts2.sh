#!/bin/bash
OUT=/mnt/d/本地项目-01/_tools/k148_xbl_ufs.dts
sed -n '1530,1640p' "$OUT"
echo '===== top-level soc children ====='
sed -n '1,60p' "$OUT"