#!/bin/bash
U=/root/k70/uefi
echo "=== consumers/producers of gEfiDtbExtensionHobGuid ==="
grep -rn "DtbExtension" $U --include=*.c --include=*.h --include=*.inf --include=*.dec 2>/dev/null | grep -v Build/ | head -20
echo
echo "=== any 'Dtb' protocol/driver in tree ==="
grep -rln "DtbExtnProtocol\|EDKII_DTB_EXTN\|DtbExtn" $U --include=*.c --include=*.h 2>/dev/null | grep -v Build/ | head -20
echo
echo "=== stock FV driver list (fv_dump) - look for dtb-ish names ==="
ls /mnt/d/本地项目-01/_k70port_extract/k70-port/extracted/fv_dump/drivers 2>/dev/null | head -60
