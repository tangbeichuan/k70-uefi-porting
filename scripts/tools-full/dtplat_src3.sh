#!/bin/bash
U=/root/k70/uefi
echo "########## DtPlatformDxe.c ##########"
sed -n '1,140p' $U/Mu_Basecore/EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.c
echo
echo "########## DtPlatformDxe.h (blob guid?) ##########"
cat $U/Mu_Basecore/EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.h
echo
echo "########## qrd8550.fdf device tree block ##########"
grep -n -B4 -A6 '25462CDA' $U/Platforms/Qualcomm/qrd8550Pkg/qrd8550.fdf
echo
echo "########## vermeer.fdf device tree block (as built, from backup) ##########"
grep -n -B6 -A6 '25462CDA' $U/Platforms/Xiaomi/vermeerPkg/vermeer.fdf
