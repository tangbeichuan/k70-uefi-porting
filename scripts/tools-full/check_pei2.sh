#!/bin/bash
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "== current dsc PlatformPeiLib lines =="
grep -n 'PlatformPeiLib' "$PKG/vermeer.dsc" || echo "  none"
echo "== dsc includes =="
grep -n '\.dsc\.inc\|include' "$PKG/vermeer.dsc" | head -10
echo "== build log mentions =="
L=/root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt
ls -l "$L" 2>/dev/null
grep -oiE 'PlatformPeiLib[A-Za-z]*' "$L" 2>/dev/null | sort | uniq -c | head
grep -oE 'PlatformPei[A-Za-z]*\.c' "$L" 2>/dev/null | sort | uniq -c | head
echo "== any PlatformPei objects in build tree =="
find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'PlatformPei*.obj' -o -name 'PlatformPei*.o' 2>/dev/null | head -10
echo "== timestamps =="
find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -path '*PlatformPei*' -name '*.o' -newermt '-2 hours' 2>/dev/null | head -10
