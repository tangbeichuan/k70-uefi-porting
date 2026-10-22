#!/bin/bash
U=/root/k70/uefi
echo "=== find DtPlatformDxe ==="
find $U -iname 'DtPlatformDxe*' -maxdepth 6 2>/dev/null | head
echo "=== find 25462CDA anywhere ==="
grep -rln "25462CDA\|25462cda" $U --include=*.inf --include=*.dec --include=*.c --include=*.h --include=*.fdf --include=*.dsc 2>/dev/null | head -20
echo "=== FdtBlob refs ==="
grep -rn "FdtBlob" $U/Platforms/Xiaomi/nuwaPkg/vermeer.fdf $U/Platforms/Xiaomi/nuwaPkg/*.fdf 2>/dev/null | head -20
