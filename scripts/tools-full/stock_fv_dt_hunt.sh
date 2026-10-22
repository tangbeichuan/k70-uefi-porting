#!/usr/bin/env bash
# 小米原厂 UEFI 卷里那个含 init_speed_params 的 FFS，是不是固件侧 DTB？
set -u
D=/mnt/d/本地项目-01/_k70port_extract/fv_dump
for f in "$D"/ffs490c0_tb_fv/ffs2aa358_t7.efi "$D"/ffs490c0_tb_fv/ffs223198_t7.efi; do
  [ -f "$f" ] || continue
  echo "=== $f  ($(stat -c %s "$f") B)"
  xxd -l 32 "$f"
  python3 - "$f" <<'PY'
import struct, sys
d=open(sys.argv[1],'rb').read()
if d[:4]==b'\xd0\r\xfe\xed':
    tot=struct.unpack_from('>I',d,4)[0]; off=struct.unpack_from('>I',d,8)[0]
    print(f"  ** FDT! totalsize={tot} off_struct={off}")
    for s in (b'init_speed_params', b'ufs0', b'ufshc', b'ufsphy', b'/soc'):
        print(f"     {'HIT' if s in d else '---'} {s.decode()}")
else:
    print("  not an FDT (magic=%s)" % d[:4].hex())
PY
  echo
done

echo "=== 原厂 FV 里还有哪些 FFS 含 ufs 关键字（可能是 DT 或 driver）==="
for f in "$D"/ffs490c0_tb_fv/*; do
  [ -f "$f" ] || continue
  if strings -a "$f" 2>/dev/null | grep -qi 'init_speed_params'; then
    printf '  %-50s %s B  magic=%s\n' "$(basename "$f")" "$(stat -c %s "$f")" "$(xxd -l 4 -p "$f")"
  fi
done

echo
echo "=== 整个 fv_dump 里有没有以 FDT magic 开头、且含 ufs0 的 blob ==="
python3 - <<'PY'
import os, struct
root='/mnt/d/本地项目-01/_k70port_extract/fv_dump'
for base, dirs, files in os.walk(root):
    for f in files:
        p=os.path.join(base,f)
        try:
            d=open(p,'rb').read()
        except Exception:
            continue
        i=0
        while True:
            i=d.find(b'\xd0\r\xfe\xed', i)
            if i<0: break
            try:
                tot=struct.unpack_from('>I',d,i+4)[0]
            except Exception:
                break
            if 64 < tot < len(d)-i+1 and tot > 1000:
                blob=d[i:i+tot]
                hits=[s.decode() for s in (b'init_speed_params',b'ufs0',b'/soc') if s in blob]
                if hits:
                    print(f"  {p} @+0x{i:X} totalsize={tot} hits={hits}")
            i+=4
PY
