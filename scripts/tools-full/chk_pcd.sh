set +e
echo "=== PcdFrameBuffer definitions ==="
grep -rn "PcdFrameBuffer" /root/k70/uefi/Silicon/Silicium/SiliciumPkg/*.dec | head
echo "=== set anywhere in platform dsc? ==="
grep -rn "PcdFrameBuffer" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc /root/k70/uefi/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc /root/k70/uefi/Silicon/Silicium/SiliciumPkg/Common.dsc.inc 2>/dev/null | head
echo "=== other platforms using it ==="
grep -rln "PcdFrameBufferWidth" /root/k70/uefi/Platforms 2>/dev/null | head -5