set +e
python3 - <<'PY'
import gzip, pathlib, hashlib, struct

for tag in ("keys146","keys147b"):
    img = pathlib.Path(f"/mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-{tag}.img").read_bytes()
    ksize, = struct.unpack_from("<I", img, 8)
    kernel = img[1088:1088+ksize] if False else None
    # kernel offset for boot v4: header(1584? ) -- find gzip magic 1f 8b
    idx = img.find(b"\x1f\x8b\x08")
    gz = img[idx:idx+ksize]
    raw = gzip.decompress(gz)
    print(tag, "img", len(img), "kernel", ksize, "gz@", idx, "raw", len(raw))
    print("   shim head", raw[:8].hex(), "fd size", len(raw)-192)
    fdsha = hashlib.sha256(raw[192:]).hexdigest()
    print("   fd sha(from img)", fdsha)
    fdp = pathlib.Path(f"/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-{tag}.fd")
    if fdp.exists():
        print("   fd sha(file)    ", hashlib.sha256(fdp.read_bytes()).hexdigest())
PY