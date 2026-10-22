#!/usr/bin/env bash
# Package the vermeer port source tree and refresh the checksums of everything
# published in K70-UEFI-build.
set +e
UEFI=/root/k70/uefi
OUT=/mnt/d/本地项目-01/K70-UEFI-build
PORT=/root/k70/vermeer-port-src
rm -rf "$PORT"; mkdir -p "$PORT"

echo "=== collect port source tree ==="
mkdir -p "$PORT/Platforms/Xiaomi" "$PORT/Resources/Configs" "$PORT/Resources/DTBs" "$PORT/Resources/MuPatches" "$PORT/Binaries"
cp -a "$UEFI/Platforms/Xiaomi/vermeerPkg" "$PORT/Platforms/Xiaomi/"
cp -a "$UEFI/Binaries/vermeer" "$PORT/Binaries/"
cp -a "$UEFI/Resources/Configs/vermeer.toml" "$PORT/Resources/Configs/"
cp -a "$UEFI/Resources/DTBs/vermeer.dtb" "$PORT/Resources/DTBs/"
cp -a "$UEFI/Resources/MuPatches/." "$PORT/Resources/MuPatches/"
# record the local changes to the upstream build script so the tree is reproducible
mkdir -p "$PORT/upstream-patches"
diff -u /root/k70/build_uefi.py.orig "$UEFI/build_uefi.py" > "$PORT/upstream-patches/build_uefi.py.diff" 2>/dev/null || \
  cp "$UEFI/build_uefi.py" "$PORT/upstream-patches/build_uefi.py"
ls "$PORT/upstream-patches/"

echo
echo "=== tar it up ==="
cd /root/k70 && tar czf "$OUT/vermeer-port-src-$(date +%Y%m%d).tar.gz" vermeer-port-src && ls -l "$OUT"/vermeer-port-src-*.tar.gz
echo "  files in tree: $(find "$PORT" -type f | wc -l)"

echo
echo "=== refresh SHA256SUMS ==="
cd "$OUT" && sha256sum *.fd *.img *.tar.gz *.TXT 2>/dev/null | grep -v vendorhw-DO-NOT-FLASH | sort -k2 > SHA256SUMS.txt
cat SHA256SUMS.txt
