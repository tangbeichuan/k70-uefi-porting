#!/bin/bash
Q=/root/k70/uefi/Silicon/Qualcomm/QcomPkg
echo "########## QcomPkg.dec : dtb / extn guids ##########"
grep -n -i "dtb\|extn" $Q/QcomPkg.dec | head -30
echo
echo "########## PlatformPei.h ##########"
cat $Q/Library/PlatformPeiLib/PlatformPei.h
echo
echo "########## XblProtocols.c (head 120) ##########"
sed -n '1,120p' $Q/Library/PlatformPeiLib/XblProtocols.c
