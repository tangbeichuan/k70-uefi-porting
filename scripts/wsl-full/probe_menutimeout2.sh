set -u
cd /root/k70/uefi
echo "=== declaration in any .dec ==="
grep -rn "PcdPlatformBootTimeOut" --include=*.dec . | head
echo
echo "=== BdsEntry.c context around the timeout use ==="
sed -n '320,370p' Mu_Basecore/MdeModulePkg/Universal/BdsDxe/BdsEntry.c
echo
echo "=== and around line 745 ==="
sed -n '740,775p' Mu_Basecore/MdeModulePkg/Universal/BdsDxe/BdsEntry.c
