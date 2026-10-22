#!/bin/bash
echo "=== grep CompareGuid definition in tree (any source) ==="
grep -rn --include=*.c --include=*.h --include=*.cpp "CompareGuid (" /root/k70/uefi/Mu_Basecore /root/k70/uefi/MdePkg 2>/dev/null | grep -v "= *CompareGuid\|Co.*CompareGuid (" | head -20
echo
echo "=== header prototype ==="
grep -rn "CompareGuid" /root/k70/uefi/Mu_Basecore/MdePkg/Include/Library/BaseLib.h 2>/dev/null | head -10
echo
echo "=== Mu BaseLib dir listing ==="
ls /root/k70/uefi/Mu_Basecore/MdePkg/Library/BaseLib/ 2>/dev/null | head -20
