#!/bin/bash
cd /mnt/d/本地项目-01/_tools || exit 1
python3 pmic_an.py show 1f520 1f760
echo '########## 1e7a0-1e960'
python3 pmic_an.py show 1e7a0 1e960
