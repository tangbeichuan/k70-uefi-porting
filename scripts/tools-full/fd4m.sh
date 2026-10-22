set +e
cd /root/k70/uefi
cp Resources/Configs/vermeer.toml /root/k70/vermeer.toml.bak125
sed -i 's/^size = 0x300000$/size = 0x400000/' Resources/Configs/vermeer.toml
grep -n 'uefi_fd' -A3 Resources/Configs/vermeer.toml
echo "=== rebuild shims with FD_SIZE 4 MiB ==="
cd BootShim
for m in 0 1; do
  make -s clean >/dev/null 2>&1
  make -s REQUIRES_KERNEL_HEADER=1 FD_BASE=0xA7100000 FD_SIZE=0x400000 PAINT_MARKER=$m >/dev/null 2>&1 || echo "make failed m=$m"
  ls -l BootShim.bin 2>/dev/null | awk '{print "built", $5, "bytes PAINT_MARKER='$m'"}'
  cp BootShim.bin /root/k70/shims/BootShim-marker${m}.bin
done
ls -l /root/k70/shims/