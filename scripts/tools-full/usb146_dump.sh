#!/bin/bash
set -u
python3 /mnt/d/本地项目-01/_tools/usb146_dump.py 2>&1 | tee /mnt/d/本地项目-01/_tools/usb146_dump.log
echo "---- log lines: $(wc -l < /mnt/d/本地项目-01/_tools/usb146_dump.log)"
