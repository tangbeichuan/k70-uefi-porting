set +e
D=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
echo "=== current debug PCDs ==="
grep -nE 'PcdDebugPrintErrorLevel|PcdDebugPropertyMask|PcdFixedDebugPrintErrorLevel' "$D"
echo "=== DEBUG mask used by our drivers ==="
grep -nE 'DEBUG \(|DEBUG\(' /mnt/d/????-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/*.c 2>/dev/null | head -5
