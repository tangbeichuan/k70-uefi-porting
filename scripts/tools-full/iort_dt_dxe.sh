#!/bin/bash
I=/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Drivers/IortDtDxe
echo "=== files ==="; ls -l $I
echo; echo "=== .inf ==="; cat $I/*.inf
echo; echo "=== .h (protocol?) ==="; cat $I/*.h 2>/dev/null | head -80
echo; echo "=== .c head 100 ==="; head -100 $I/*.c
