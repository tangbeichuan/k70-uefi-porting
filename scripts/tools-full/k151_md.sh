#!/bin/bash
Q=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
T=/mnt/d/本地项目-01/_tools
G=9c5e7a31-4b28-4f6d-8a19-2d7c6e5b3a84
echo "=== logdisk: keys151 vs keys151b ==="
python3 $T/k151_moddiff.py $Q/SILICIUM_UEFI-keys151.fd $Q/SILICIUM_UEFI-keys151b.fd $G
echo "=== logdisk: keys149 vs keys151b ==="
python3 $T/k151_moddiff.py $Q/SILICIUM_UEFI-keys149.fd $Q/SILICIUM_UEFI-keys151b.fd $G
echo "=== logdisk: keys149 vs keys151 ==="
python3 $T/k151_moddiff.py $Q/SILICIUM_UEFI-keys149.fd $Q/SILICIUM_UEFI-keys151.fd $G
G2=5b21e7c4-3d18-4f6a-9a20-8c7e51fd42b9
echo "=== dtbextn: keys149 vs keys151b ==="
python3 $T/k151_moddiff.py $Q/SILICIUM_UEFI-keys149.fd $Q/SILICIUM_UEFI-keys151b.fd $G2
