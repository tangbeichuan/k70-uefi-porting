set +e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi
echo "=== initial bytes at file off 0x1E060..0x1E0A0 (global 0x1E078 window) ==="
xxd -s 0x1E060 -l 0x40 "$F"
echo "=== all refs to global 0x1E078 ==="
llvm-objdump -d "$F" 2>/dev/null | grep -nE '1e000|#0x78' | grep -E '1e000' | head -60
echo "=== who stores to it (str .*\[x.., #0x78\]) ==="
llvm-objdump -d "$F" 2>/dev/null | grep -E 'str.*#0x78\]' | head -40
