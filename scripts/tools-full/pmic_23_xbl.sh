#!/bin/bash
D=/mnt/d/本地项目-01/_k70port_extract/fv_dump/drivers
echo '--- EnvDxe bytes at 0xe098 (candidate HOB GUID)'
xxd -s 0xe098 -l 16 "$D/EnvDxe.efi"
echo '--- EnvDxe bytes at 0xe470 (static iface template, first 0x40)'
xxd -s 0xe470 -l 0x40 "$D/EnvDxe.efi"
echo '--- EnvDxe sections'
llvm-readobj --sections "$D/EnvDxe.efi" | grep -E 'Name|Address|Offset|Size' | head -40
echo '--- xbl_a.img head'
xxd -l 0x80 /root/k70/rt/xbl_a.img
echo '--- ELF magic count in xbl_a.img'
python3 - <<'EOF'
b=open('/root/k70/rt/xbl_a.img','rb').read()
import re
offs=[m.start() for m in re.finditer(rb'\x7fELF', b)]
print('ELF count', len(offs), [hex(o) for o in offs[:20]])
# also search for aarch64 PE 'MZ'
print('len', len(b))
EOF
