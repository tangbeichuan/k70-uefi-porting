#!/bin/bash
set -u
echo "=== _tools scripts with fv/decomp/lzma/fd in name ==="
ls /mnt/d/本地项目-01/_tools/ | grep -Ei "fv|decomp|lzma|tiano|_fd|fd_"
echo
echo "=== _k70port_extract top level ==="
ls /mnt/d/本地项目-01/_k70port_extract/
echo
echo "=== fv_dump ==="
ls /mnt/d/本地项目-01/_k70port_extract/fv_dump/ 2>/dev/null | head -20
echo
echo "=== any python uefi tooling available? ==="
python3 -c "import uefi_firmware" 2>&1 | head -2
which UEFITool UEFIExtract 2>/dev/null
ls /mnt/d/本地项目-01/_k70port_extract/*.py 2>/dev/null | head
