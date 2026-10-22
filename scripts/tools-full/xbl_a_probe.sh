#!/bin/bash
F="/mnt/d/本地项目-01/.dsh-im/inbound/20261020-183502-SmiQOg/01-06f41ecb-3e57-4f10-be7c-31aade3635e4_xbl_a.img"
echo "=== size / sha ==="
stat -c%s "$F"; sha256sum "$F" | cut -c1-64
echo
echo "=== head 32 bytes ==="
xxd -l 32 "$F"
echo
echo "=== FDT magics (d00dfeed, big-endian) ==="
python3 - "$F" <<'PY'
import sys,struct
d=open(sys.argv[1],'rb').read()
print('len',len(d))
magic=b'\xd0\x0d\xfe\xed'
off=0; hits=[]
while True:
    i=d.find(magic,off)
    if i<0: break
    # tot size is field at +4 (big endian)
    tot=struct.unpack('>I',d[i+4:i+8])[0] if i+8<=len(d) else 0
    hits.append((hex(i),tot))
    off=i+1
print('count',len(hits))
for h in hits[:20]: print('  off',h[0],'totalsize',h[1])
PY
