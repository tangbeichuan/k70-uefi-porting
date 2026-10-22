#!/usr/bin/env bash
# 反汇编 nuwa UFSDxe 补丁点（文件偏移 0x9574），判断它到底改了什么逻辑。
set -u
R=/mnt/d/本地项目-01/_k70port_extract
P=$R/port/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.patched.efi

echo "=== available disassemblers ==="
for t in aarch64-linux-gnu-objdump llvm-objdump objdump; do command -v $t >/dev/null 2>&1 && echo "  OK $t"; done
echo

DIS=""
command -v aarch64-linux-gnu-objdump >/dev/null 2>&1 && DIS="aarch64-linux-gnu-objdump"
[ -z "$DIS" ] && command -v llvm-objdump >/dev/null 2>&1 && DIS="llvm-objdump"
[ -z "$DIS" ] && DIS="objdump"
echo "using: $DIS"
echo

# PE headers: 找 .text 段的 RVA / PointerToRawData，判断 0x9574 落在哪个段
python3 - "$P" <<'PY'
import struct, sys
d = open(sys.argv[1], 'rb').read()
pe = struct.unpack_from('<I', d, 0x3c)[0]
nsec = struct.unpack_from('<H', d, pe + 6)[0]
opt = struct.unpack_from('<H', d, pe + 20)[0]
sec0 = pe + 24 + opt
print("PE sections:")
for i in range(nsec):
    o = sec0 + i * 40
    name = d[o:o+8].rstrip(b'\0').decode('latin1')
    vsz, va, rawsz, rawptr = struct.unpack_from('<IIII', d, o+8)
    print(f"  {name:8s} VA=0x{va:08X} VSz=0x{vsz:X} RawPtr=0x{rawptr:X} RawSz=0x{rawsz:X}")
    if rawptr <= 0x9574 < rawptr + rawsz:
        print(f"    -> file offset 0x9574 is inside {name}, RVA=0x{0x9574 - rawptr + va:08X}")
PY
echo

for off in 0x9500; do
  echo "=== disassembly around 0x9574 (raw binary, base=$off) ==="
  if [ "$DIS" = "llvm-objdump" ]; then
    "$DIS" --triple=aarch64 -d --start-address=$off --stop-address=$((off+0xb0)) "$P" 2>/dev/null | tail -40
  else
    "$DIS" -D -b binary -m aarch64 --start-address=$off --stop-address=$((off+0xb0)) "$P" 2>/dev/null | tail -40
  fi
done
