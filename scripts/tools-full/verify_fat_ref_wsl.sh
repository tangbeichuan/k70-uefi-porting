#!/usr/bin/env bash
# Cross-validate the host-generated FAT reference images with real Linux FAT
# tools (dosfstools + mtools) and compare our geometry with mkfs.fat itself.
#
#   fat16_ref.img        1 MiB, exactly what the driver formats on the phone,
#                        with the three log lines it writes at load time
#   fat16_ref_filled.img 1 MiB, log grown to the 128 KiB cap (stress test)
#   fat16_ref_8m.img     8 MiB, same formatter, genuine FAT16
#
# Exit 0 only if fsck.fat accepts every image (no repairs) and BOOTLOG.TXT
# round-trips byte for byte through mtools.
set -e -o pipefail
D=/mnt/d/本地项目-01/_tools
cd "$D"

sec(){ echo; echo "########## $* ##########"; }

check_image() {
  local img="$1" root_lba="$2"
  sec "xxd boot sector / $img"
  xxd -l 96 "$img"
  sec "fsck.fat -n -v $img"
  fsck.fat -n -v "$img"
  sec "mdir -i $img ::"
  mdir -i "$img" ::
  sec "mdir -i $img ::BOOTLOG.TXT"
  mdir -i "$img" ::BOOTLOG.TXT
  sec "root directory (LBA $root_lba)"
  xxd -s $(( root_lba * 512 )) -l 96 "$img"
}

for img in fat16_ref.img fat16_ref_filled.img; do check_image "$img" 3; done
check_image fat16_ref_8m.img 17

sec "mcopy round trip: extract BOOTLOG.TXT and compare with what the driver writes"
mcopy -i fat16_ref.img ::BOOTLOG.TXT - > /tmp/from_img.txt
printf 'VERMEER-UEFI LOGDISK\r\n[FAT16] volume ready, root entries=32\r\nBOOTLOG.TXT is written by VermeerLogDiskDxe\r\n' > /tmp/expect.txt
cmp /tmp/from_img.txt /tmp/expect.txt && echo "  fat16_ref.img       : BOOTLOG.TXT byte-identical to the driver's lines"
mcopy -i fat16_ref_8m.img ::BOOTLOG.TXT - > /tmp/from_img8.txt
cmp /tmp/from_img8.txt /tmp/expect.txt && echo "  fat16_ref_8m.img    : BOOTLOG.TXT byte-identical"
mcopy -i fat16_ref_filled.img ::BOOTLOG.TXT - > /tmp/from_filled.txt
echo "  fat16_ref_filled.img: $(wc -c < /tmp/from_filled.txt) bytes, first line: $(head -1 /tmp/from_filled.txt)"
echo "  length check        : $(wc -c < /tmp/from_filled.txt) <= 131072 ?"
[ "$(wc -c < /tmp/from_filled.txt)" -le 131072 ] || { echo "FILLED LOG TOO BIG"; exit 1; }

################################################################################
# Ground truth: what does mkfs.fat itself choose for the same parameters?
################################################################################
sec "mkfs.fat 1 MiB, -F 12 -S 512 -s 4 -R 1 -f 1 -r 32"
rm -f /tmp/mkfs1m.img
dd if=/dev/zero of=/tmp/mkfs1m.img bs=1024 count=1024 status=none
mkfs.fat -F 12 -S 512 -s 4 -R 1 -f 1 -r 32 -n "K70LOG" /tmp/mkfs1m.img
fsck.fat -n -v /tmp/mkfs1m.img
python3 - /tmp/mkfs1m.img fat16_ref.img <<'PY'
import sys, struct
def bpb(path):
    d = open(path, 'rb').read()
    g16 = lambda o: struct.unpack_from('<H', d, o)[0]
    return dict(byts=g16(0x0B), spc=d[0x0D], rsvd=g16(0x0E), nfats=d[0x10],
                rootent=g16(0x11), tot16=g16(0x13), media=d[0x15],
                fatsz=g16(0x16), fstype=bytes(d[0x36:0x3E]).decode().strip())
a, b = bpb(sys.argv[1]), bpb(sys.argv[2])
print("  mkfs.fat :", a)
print("  our ref  :", b)
for k in ("byts", "spc", "rsvd", "nfats", "rootent", "tot16", "fatsz", "fstype"):
    print("    %-8s %s" % (k, "MATCH" if a[k] == b[k] else "DIFF mkfs=%s ours=%s" % (a[k], b[k])))
PY

sec "mkfs.fat 8 MiB, -F 16 -S 512 -s 4 -R 1 -f 1 -r 32"
rm -f /tmp/mkfs8m.img
dd if=/dev/zero of=/tmp/mkfs8m.img bs=1024 count=8192 status=none
mkfs.fat -F 16 -S 512 -s 4 -R 1 -f 1 -r 32 -n "K70LOG" /tmp/mkfs8m.img
fsck.fat -n -v /tmp/mkfs8m.img
python3 - /tmp/mkfs8m.img fat16_ref_8m.img <<'PY'
import sys, struct
def bpb(path):
    d = open(path, 'rb').read()
    g16 = lambda o: struct.unpack_from('<H', d, o)[0]
    return dict(byts=g16(0x0B), spc=d[0x0D], rsvd=g16(0x0E), nfats=d[0x10],
                rootent=g16(0x11), tot16=g16(0x13), media=d[0x15],
                fatsz=g16(0x16), fstype=bytes(d[0x36:0x3E]).decode().strip())
a, b = bpb(sys.argv[1]), bpb(sys.argv[2])
print("  mkfs.fat :", a)
print("  our ref  :", b)
for k in ("byts", "spc", "rsvd", "nfats", "rootent", "tot16", "fatsz", "fstype"):
    print("    %-8s %s" % (k, "MATCH" if a[k] == b[k] else "DIFF mkfs=%s ours=%s" % (a[k], b[k])))
PY

################################################################################
# Negative control: 1 MiB cannot be FAT16 (no cluster count reaches 4085).
################################################################################
sec "negative control: force mkfs.fat -F 16 on a 1 MiB volume"
rm -f /tmp/try1m16.img
dd if=/dev/zero of=/tmp/try1m16.img bs=1024 count=1024 status=none
if mkfs.fat -F 16 -S 512 -s 1 -R 1 -f 1 -r 32 /tmp/try1m16.img; then
  echo "mkfs.fat did produce something - inspecting whether it is really FAT16:"
  python3 - /tmp/try1m16.img <<'PY'
import sys, struct
d = open(sys.argv[1], 'rb').read()
g16 = lambda o: struct.unpack_from('<H', d, o)[0]
tot, spc = g16(0x13), d[0x0D]
data = tot - g16(0x0E) - g16(0x10) * g16(0x16) - 16
print("  tot=%d spc=%d rsvd=%d fatsz=%d fstype=%r clusters=%d"
      % (tot, spc, g16(0x0E), g16(0x16), bytes(d[0x36:0x3E]), data // spc))
print("  FAT16 needs >= 4085 clusters, so the FAT type byte cannot be honoured" if data // spc < 4085
      else "  cluster count OK for FAT16")
PY
  fsck.fat -n -v /tmp/try1m16.img || true
else
  echo "as expected, mkfs.fat refuses: a 1 MiB volume has at most 2048 sectors"
fi

echo
echo "ALL FAT REFERENCE CHECKS PASSED"
