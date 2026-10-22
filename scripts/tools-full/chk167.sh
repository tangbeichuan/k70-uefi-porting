#!/bin/bash
# chk167.sh -- keys167 specific checks
set -u
MENU=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe/DEBUG/VermeerMenuDxe.efi
[ -s "$MENU" ] || MENU=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerMenuDxe.efi
echo "=== Menu: $MENU ($(stat -c%s "$MENU") B) ==="
for s in "[167] setup bm=" "-> desc-device" "desc-config" "set-address" "set-config" \
         "[167] configured cfg=" "[167] ep0 armed" "[167] done: evts=" \
         "[167] dev evt type=" "K70-0001" "Vermeer" "K70 UEFI DEBUG"; do
  a=$(grep -a -c "$s" "$MENU" || true)
  u=$(python3 - "$MENU" "$s" <<'PY'
import sys
data = open(sys.argv[1],'rb').read()
print(data.count(sys.argv[2].encode('utf-16-le')))
PY
)
  printf '  %-32s ascii=%s utf16=%s\n' "$s" "$a" "$u"
done
echo "=== descriptor PID bytes (expect ... 0x01 0x00 0x00 0x01 ...) ==="
python3 - "$MENU" <<'PY'
import sys
d = open(sys.argv[1],'rb').read()
# device descriptor as byte array emitted by clang: 18,1,0x00,0x02,0,0,0,64,0x09,0x12,0x01,0x00,0x00,0x01,1,2,3,1
pat = bytes([18,1,0x00,0x02,0,0,0,64,0x09,0x12,0x01,0x00,0x00,0x01,1,2,3,1])
print("  devdesc pattern found:", d.count(pat), "(expect >=1)")
# config descriptor
pat2 = bytes([9,2,18,0,1,1,0,0x80,250, 9,4,0,0,0,0xFF,0x00,0x00,0])
print("  cfgdesc pattern found:", d.count(pat2), "(expect >=1)")
print("  old PID 0xC101 pattern found:", d.count(bytes([18,1,0x00,0x02,0,0,0,64,0x09,0x12,0x01,0xC1,0x00,0x01,1,2,3,1])), "(expect 0)")
PY
echo "=== dep cmd immediates ==="
llvm-objdump -d "$MENU" 2>/dev/null | grep -E 'mov[[:space:]]+w[0-9]+, #0xc(800|c700|40c|c400|c408|c70[0-9a-f])|movk[[:space:]]+w[0-9]+, #0xa60' | head -20
echo "=== wTotalLength literal 18,2 = fine; check STALL cmd path (0x4) ==="
llvm-objdump -d "$MENU" 2>/dev/null | grep -c 'mov[[:space:]]*w[0-9]*, #0x4' || true
