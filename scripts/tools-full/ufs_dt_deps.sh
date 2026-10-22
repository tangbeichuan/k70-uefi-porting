#!/usr/bin/env bash
# UFSDxe 到底怎么拿 DT：找 FdtClient 协议名 / DTB 表 GUID / DT 路径字符串。
set -u
cd /root/k70/uefi || exit 1
B=Binaries/vermeer/QcomPkg/Drivers/UFSDxe
echo "=== strings 里与 fdt/dt/ufs 路径相关的 ==="
strings -a -n 6 "$B/UFSDxe.patched.efi" | grep -iE 'fdt|dtb|/soc|ufs[0-9]?/|init_speed|perf_speed|timeout_values|vcc' | head -40
echo
echo "=== 打印所有 /xxx 开头的 DT 路径样式字符串 ==="
strings -a -n 6 "$B/UFSDxe.patched.efi" | grep -E '^/' | head -40
echo
echo "=== GUID 十六进制串（以列表看是否含 FdtClient/Fdt 表 GUID）==="
strings -a -n 8 "$B/UFSDxe.patched.efi" | grep -iE 'client|protocol' | head -12
echo
echo "=== Mu 树里 EmbeddedPkg 目录 ==="
ls Mu_Basecore/EmbeddedPkg/Drivers 2>/dev/null
echo "--- Library ---"
ls Mu_Basecore/EmbeddedPkg/Library 2>/dev/null | head -30
echo
echo "=== FdtClientDxe.inf / 任何 DtbLoader 库 ==="
find Mu_Basecore/EmbeddedPkg -name '*.inf' | xargs grep -ln 'FdtClient\|DtbLoader' 2>/dev/null | head
