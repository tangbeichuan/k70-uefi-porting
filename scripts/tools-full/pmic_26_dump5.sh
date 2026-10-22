#!/bin/bash
cd /mnt/d/本地项目-01/_tools || exit 1
echo '===== 1f784 - 1f8a0'
python3 pmic_an.py show 1f784 1f8a0
echo '===== 1f8a0 - 1f9c0'
python3 pmic_an.py show 1f8a0 1f9c0
echo '===== 1f9c0 - 1fae0'
python3 pmic_an.py show 1f9c0 1fae0
echo '===== 1e3d0 - 1e4d0'
python3 pmic_an.py show 1e3d0 1e4d0
