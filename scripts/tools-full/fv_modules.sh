#!/bin/bash
G=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref
echo "=== xref: $G"
wc -l "$G"
echo "--- key modules ---"
grep -Ei 'Shell|Fat|Gop|Ufs|ScsiDisk|Partition|DiskIo|Variable|HiiData|BootManager|Console|Terminal|Graphics|Logo' "$G" | sed 's/^ *//' | sort -k2 | head -60
