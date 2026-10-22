set +e
python3 - <<'PY'
import struct
for p in ['/root/k70/shims/BootShim-marker0.bin','/root/k70/shims/BootShim-marker1.bin']:
    d=open(p,'rb').read()
    text_off, image_size = struct.unpack_from('<QQ', d, 8)
    print(p, 'size', len(d), 'text_off', hex(text_off), 'image_size', hex(image_size))
PY
ls -l /root/k70/uefi/BootShim/