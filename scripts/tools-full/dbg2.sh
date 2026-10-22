#!/bin/bash
cd /root/k70/uefi || exit 1
echo "=== every ASSERT (Format != NULL) with file:line ==="
grep -rn 'ASSERT (Format != NULL)' --include=*.c . 2>/dev/null | sed 's#^\./##' | sort -t: -k3 -n | head -40
echo
echo "=== files whose assert is at line 78 ==="
grep -rn 'ASSERT (Format != NULL)' --include=*.c . 2>/dev/null | awk -F: '$3==78 {print}'
echo
echo "=== which DebugLib is used by DXE drivers in vermeer.dsc ==="
grep -n "DebugLib\|SerialPortLib\|ReportStatusCode" Platforms/Xiaomi/vermeerPkg/vermeer.dsc 2>/dev/null | head -30
echo
echo "=== DXE arch dsc/inc DebugLib default ==="
grep -rn "DebugLib" Platforms/Xiaomi/vermeerPkg/Include/*.inc 2>/dev/null | head -20
