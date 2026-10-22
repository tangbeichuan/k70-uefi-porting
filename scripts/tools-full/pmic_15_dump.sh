#!/bin/bash
cd /mnt/d/本地项目-01/_tools || exit 1
python3 pmic_an.py show 1f090 1f260
echo '########## 1e2a0-1e450'
python3 pmic_an.py show 1e2a0 1e450
