#!/usr/bin/env bash
# Build the two boot-image variants and publish them with distinct names.
#   primary  : header_version = 1 (same as nuwa, the other SM8550 Xiaomi device)
#   fallback : header_version = 0 (what sheng, verified working, uses)
set +e
UE=/root/k70/uefi
OUT=/mnt/d/本地项目-01/K70-UEFI-build
TOML=$UE/Resources/Configs/vermeer.toml
cd "$UE" || exit 1
. /root/k70/venv/bin/activate

build() {
  local hdr="$1" name="$2"
  sed -i "s/^header_version = .*/header_version = $hdr/" "$TOML"
  echo "===== building $name (header_version=$hdr) ====="
  python3 build_uefi.py -d vermeer -m 0 -r DEBUG > /root/k70/build-$name.log 2>&1
  local rc=$?
  if [ $rc -ne 0 ]; then
    echo "BUILD FAILED (rc=$rc)"; tail -20 /root/k70/build-$name.log; return 1
  fi
  cp -f "$UE/Mu-vermeer.img" "$OUT/$name.img"
  echo "  -> $OUT/$name.img  $(stat -c%s "$OUT/$name.img") bytes"
  python3 - "$OUT/$name.img" <<'PY'
import struct, sys, hashlib
d = open(sys.argv[1], "rb").read()
hv, ps = struct.unpack_from("<I", d, 8 + 32)[0], struct.unpack_from("<I", d, 8 + 28)[0]
ks = struct.unpack_from("<I", d, 8)[0]
print(f"     header_version={hv} page_size={ps} kernel_size={ks} sha256={hashlib.sha256(d).hexdigest()}")
PY
}

build 1 "Mu-vermeer"
build 0 "Mu-vermeer-hdr0"

echo "===== restoring primary config (header_version = 1) ====="
sed -i "s/^header_version = .*/header_version = 1/" "$TOML"
grep -n header_version "$TOML"
cp -f "$UE/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd" "$OUT/SILICIUM_UEFI.fd"
cd "$OUT" && sha256sum Mu-vermeer.img Mu-vermeer-hdr0.img SILICIUM_UEFI.fd | tee SHA256SUMS.txt
