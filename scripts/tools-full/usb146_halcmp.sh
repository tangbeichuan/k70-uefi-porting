#!/bin/bash
# usb146_halcmp.sh -- run the HALIOMMU FV-vs-Binaries comparison
set -u
python3 /mnt/d/本地项目-01/_tools/usb146_halcmp.py 2>&1 | tee /mnt/d/本地项目-01/_tools/usb146_halcmp.log
