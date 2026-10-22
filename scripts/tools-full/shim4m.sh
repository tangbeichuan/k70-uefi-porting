set +e
cd /root/k70/uefi/BootShim
for m in 0 1; do
  rm -f BootShim.elf BootShim.bin
  make -s REQUIRES_KERNEL_HEADER=1 FD_BASE=0xA7100000 FD_SIZE=0x400000 PAINT_MARKER=$m >/dev/null 2>&1
  cp BootShim.bin /root/k70/shims/BootShim-marker${m}.bin
done
python3 - <<'PY'
import struct
for p in ['/root/k70/shims/BootShim-marker0.bin','/root/k70/shims/BootShim-marker1.bin']:
    d=open(p,'rb').read()
    t,s = struct.unpack_from('<QQ', d, 8)
    print(p, len(d), hex(t), hex(s))
PY